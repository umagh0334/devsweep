// Ed25519 릴리스 서명 도구 — 자동 업데이트 신뢰경계용. 외부 의존성 0 (CryptoKit 내장).
//
//   swift tools/ed25519.swift keygen              → PRIVATE=/PUBLIC= (base64, 32바이트 raw) 출력
//   swift tools/ed25519.swift sign <key> <file>   → 파일의 base64 서명 출력
//
// 개인키는 **repo 밖**(~/.config/devsweep/update_ed25519.key)에만 두고 절대 커밋하지 않는다.
// 공개키는 AppInfo.updatePublicKeyB64 로 앱에 박혀 배포되며, 앱은 이 키로 릴리스 zip 서명을 검증한다.
import Foundation
import CryptoKit

func die(_ m: String) -> Never {
    FileHandle.standardError.write(Data((m + "\n").utf8))
    exit(1)
}

let args = CommandLine.arguments

switch args.count > 1 ? args[1] : "" {
case "keygen":
    let k = Curve25519.Signing.PrivateKey()
    print("PRIVATE=" + k.rawRepresentation.base64EncodedString())
    print("PUBLIC=" + k.publicKey.rawRepresentation.base64EncodedString())

case "sign":
    guard args.count == 4 else { die("usage: sign <keyfile> <file>") }
    guard let keyText = try? String(contentsOfFile: args[2], encoding: .utf8),
          let keyData = Data(base64Encoded: keyText.trimmingCharacters(in: .whitespacesAndNewlines)),
          let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: keyData)
    else { die("개인키를 읽을 수 없음: \(args[2])") }
    guard let data = FileManager.default.contents(atPath: args[3]) else { die("파일 없음: \(args[3])") }
    guard let sig = try? key.signature(for: data) else { die("서명 실패") }
    print(sig.base64EncodedString())

case "verify":   // 로컬 점검용: verify <pubB64> <sigfile> <file>
    guard args.count == 5 else { die("usage: verify <pubB64> <sigfile> <file>") }
    guard let pubData = Data(base64Encoded: args[2]),
          let pub = try? Curve25519.Signing.PublicKey(rawRepresentation: pubData)
    else { die("공개키 오류") }
    guard let sigText = try? String(contentsOfFile: args[3], encoding: .utf8),
          let sig = Data(base64Encoded: sigText.trimmingCharacters(in: .whitespacesAndNewlines))
    else { die("서명 파일 오류") }
    guard let data = FileManager.default.contents(atPath: args[4]) else { die("파일 없음") }
    print(pub.isValidSignature(sig, for: data) ? "OK" : "INVALID")
    exit(pub.isValidSignature(sig, for: data) ? 0 : 1)

default:
    die("usage: ed25519.swift keygen | sign <keyfile> <file> | verify <pubB64> <sigfile> <file>")
}
