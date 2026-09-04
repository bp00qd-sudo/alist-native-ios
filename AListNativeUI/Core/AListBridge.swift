import Foundation

@_silgen_name("AListEngineNew") private func AListEngineNew(_ dataDir: UnsafePointer<CChar>, _ password: UnsafePointer<CChar>) -> UInt
@_silgen_name("AListEngineStart") private func AListEngineStart(_ handle: UInt) -> Int32
@_silgen_name("AListEngineStop") private func AListEngineStop(_ handle: UInt) -> Int32
@_silgen_name("AListEngineURL") private func AListEngineURL(_ handle: UInt) -> UnsafeMutablePointer<CChar>
@_silgen_name("AListEngineStatusJSON") private func AListEngineStatusJSON(_ handle: UInt) -> UnsafeMutablePointer<CChar>
@_silgen_name("AListEngineFree") private func AListEngineFree(_ handle: UInt)
@_silgen_name("AListFreeString") private func AListFreeString(_ value: UnsafeMutablePointer<CChar>)

@MainActor
final class AListBridge {
    private var handle: UInt = 0

    func start(dataDirectory: String, password: String) -> Result<String, Error> {
        stop()
        handle = dataDirectory.withCString { directory in
            password.withCString { secret in AListEngineNew(directory, secret) }
        }
        guard handle != 0 else { return .failure(BridgeError.engineCreateFailed) }
        guard AListEngineStart(handle) == 0 else {
            let status = statusText(); stop()
            return .failure(BridgeError.engineStartFailed(status))
        }
        let pointer = AListEngineURL(handle)
        defer { AListFreeString(pointer) }
        return .success(String(cString: pointer))
    }

    func stop() {
        guard handle != 0 else { return }
        _ = AListEngineStop(handle)
        AListEngineFree(handle)
        handle = 0
    }

    func statusText() -> String {
        guard handle != 0 else { return "无有效引擎" }
        let pointer = AListEngineStatusJSON(handle)
        defer { AListFreeString(pointer) }
        return String(cString: pointer)
    }

    deinit {
        if handle != 0 { _ = AListEngineStop(handle); AListEngineFree(handle) }
    }

    enum BridgeError: LocalizedError {
        case engineCreateFailed
        case engineStartFailed(String)
        var errorDescription: String? {
            switch self {
            case .engineCreateFailed: return "AList Go 引擎创建失败"
            case .engineStartFailed(let detail): return "AList Go 服务启动失败：\(detail)"
            }
        }
    }
}
