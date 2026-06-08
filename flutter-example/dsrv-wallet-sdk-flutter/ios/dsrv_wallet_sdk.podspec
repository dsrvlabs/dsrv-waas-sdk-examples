Pod::Spec.new do |s|
  s.name             = 'dsrv_wallet_sdk'
  s.version          = '0.9.0'
  s.summary          = 'DSRV MPC Wallet SDK for Flutter'
  s.description      = 'Flutter plugin for DSRV MPC-based non-custodial wallet'
  s.homepage         = 'https://dsrv.com'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'DSRV' => 'dev@dsrv.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  # iOS SDK 가 iOS 18+ Passkey PRF API 를 포함하지만 모두 #available(iOS 18) 가드 처리.
  # 그 미만 디바이스는 BackupTier.tierB (LocalAuthentication + iCloud Keychain) 로 fallback.
  s.platform         = :ios, '14.0'
  # 플러그인은 얇은 브릿지라 Swift 5 모드로 충분. (Swift 6 로 빌드된 SDK framework 소비 가능)
  s.swift_version    = '5.0'
  # native DSRVWallet SDK + MPC 네이티브를 함께 벤더.
  # dsrv_wallet_sdk_ios.xcframework 는 ios SDK 의 build_sdk.sh 로 생성 후 Frameworks/ 에 배치.
  s.vendored_frameworks = 'Frameworks/dsrv_wallet_sdk_ios.xcframework', 'Frameworks/Mpe.xcframework'
end
