import Flutter
import FoundationModels
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var foundationModelsChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "weather_friend/foundation_models",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(
          FlutterError(
            code: "bridge_unavailable",
            message: "Foundation Models bridge is unavailable.",
            details: nil
          )
        )
        return
      }

      switch call.method {
      case "checkAvailability":
        result(self.foundationModelAvailability())
      case "generateReply":
        self.generateReply(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    foundationModelsChannel = channel
  }

  private func foundationModelAvailability() -> [String: String] {
    guard #available(iOS 26.0, *) else {
      return ["status": "unsupported_os"]
    }

    let model = SystemLanguageModel.default
    switch model.availability {
    case .available:
      guard model.supportsLocale(Locale(identifier: "ko_KR")) else {
        return ["status": "unsupported_language"]
      }
      return ["status": "available"]
    case .unavailable(.deviceNotEligible):
      return ["status": "device_not_eligible"]
    case .unavailable(.appleIntelligenceNotEnabled):
      return ["status": "apple_intelligence_not_enabled"]
    case .unavailable(.modelNotReady):
      return ["status": "model_not_ready"]
    @unknown default:
      return ["status": "unknown"]
    }
  }

  private func generateReply(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 26.0, *) else {
      result(
        FlutterError(
          code: "model_unavailable",
          message: "iOS 26 or later is required.",
          details: nil
        )
      )
      return
    }
    guard
      let arguments = call.arguments as? [String: Any],
      let instructions = arguments["instructions"] as? String,
      let prompt = arguments["prompt"] as? String
    else {
      result(
        FlutterError(
          code: "invalid_arguments",
          message: "Instructions and prompt are required.",
          details: nil
        )
      )
      return
    }

    let availability = foundationModelAvailability()
    guard availability["status"] == "available" else {
      result(
        FlutterError(
          code: "model_unavailable",
          message: availability["status"],
          details: nil
        )
      )
      return
    }

    var backgroundTask = UIBackgroundTaskIdentifier.invalid
    backgroundTask = UIApplication.shared.beginBackgroundTask(
      withName: "CharacterReply"
    ) {
      if backgroundTask != .invalid {
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
      }
    }

    Task { @MainActor in
      defer {
        if backgroundTask != .invalid {
          UIApplication.shared.endBackgroundTask(backgroundTask)
          backgroundTask = .invalid
        }
      }

      do {
        let reply = try await self.respond(
          instructions: instructions,
          prompt: prompt
        )
        result(reply)
      } catch let error as LanguageModelSession.GenerationError {
        print("[FoundationModels] generation error: \(String(reflecting: error))")
        result(self.flutterError(for: error))
      } catch {
        print(
          "[FoundationModels] unexpected error: "
            + "\(String(reflecting: error))"
        )
        result(
          FlutterError(
            code: "generation_failed",
            message: error.localizedDescription,
            details: String(reflecting: error)
          )
        )
      }
    }
  }

  @available(iOS 26.0, *)
  private func respond(instructions: String, prompt: String) async throws -> String {
    var lastError: Error?

    for attempt in 0..<2 {
      do {
        let session = LanguageModelSession(instructions: instructions)
        let response = try await session.respond(
          to: prompt,
          options: GenerationOptions(
            sampling: .random(probabilityThreshold: 0.92),
            temperature: 0.8,
            maximumResponseTokens: 220
          )
        )
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
      } catch let error as LanguageModelSession.GenerationError {
        lastError = error
        let shouldRetry: Bool
        switch error {
        case .rateLimited, .concurrentRequests, .assetsUnavailable:
          shouldRetry = true
        default:
          shouldRetry = self.containsModelManagerError(error, code: 1008)
        }

        if shouldRetry && attempt == 0 {
          try await Task.sleep(for: .milliseconds(900))
          continue
        }
        throw error
      }
    }

    throw lastError ?? CocoaError(.coderInvalidValue)
  }

  @available(iOS 26.0, *)
  private func flutterError(
    for error: LanguageModelSession.GenerationError
  ) -> FlutterError {
    if containsModelManagerError(error, code: 1008) {
      return FlutterError(
        code: "model_service_failed",
        message: "Apple Intelligence model service failed.",
        details: String(reflecting: error)
      )
    }

    let code: String
    switch error {
    case .exceededContextWindowSize:
      code = "context_too_large"
    case .guardrailViolation:
      code = "guardrail_violation"
    case .rateLimited:
      code = "rate_limited"
    case .concurrentRequests:
      code = "concurrent_requests"
    case .assetsUnavailable:
      code = "model_unavailable"
    case .refusal:
      code = "refusal"
    case .unsupportedLanguageOrLocale:
      code = "unsupported_language"
    default:
      code = "generation_failed"
    }

    return FlutterError(
      code: code,
      message: error.localizedDescription,
      details: String(reflecting: error)
    )
  }

  private func containsModelManagerError(_ error: Error, code: Int) -> Bool {
    let nsError = error as NSError
    if nsError.domain == "ModelManagerServices.ModelManagerError",
      nsError.code == code
    {
      return true
    }

    if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error,
      containsModelManagerError(underlying, code: code)
    {
      return true
    }

    if let multiple = nsError.userInfo[NSMultipleUnderlyingErrorsKey] as? [Error] {
      return multiple.contains {
        containsModelManagerError($0, code: code)
      }
    }

    return false
  }
}
