# Readme
### Using the Swift SDK

The Swift SDK allows you to capture certain device signals that will be reported back to Prelude.

It is provided as a regular Swift package that you can [import as a dependency directly into your iOS application](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app).

Usage of the SDK is very simple, you just need to configure it with your SDK key (you can find it in your Prelude Dashboard) and call a single dispatch function:

```
let configuration = Configuration(sdkKey: "sdk_XXXXXXXXXXXX")
let prelude = Prelude(configuration)
let dispatchID = try? await prelude.dispatchSignals()
```

Once you get the dispatch ID you can report it back to your own API to be forwarded in subsequent network calls.

There is no restriction on when to call this API, you just need to take this action before you need to report back the dispatch ID. It is advisable to make the request early on during the user onboarding process to have the dispatch id available when required.

#### CocoaPods integration

We currently do not offer CocoaPods integration for the SDK, but creating one is a relatively straight forward process.
The steps to take are:

- Download the sourcecode from this repository, for example to a directory like `prelude-apple-sdk/sdk`.
- Open the `Package.swift` file and copy the url for the Core sdk defined in the binary target (similar to `https://prelude-public.s3.amazonaws.com/sdk/releases/apple/core/X.X.X/PreludeCore-X.X.X.xcframework.zip`).
- Download the Core SDK from that url and unzip it to a subdirectory of the one above (for example `prelude-apple-sdk/sdk/core`). You should have a single subdirectory `PreludeCore.xcframework` under `prelude-apple-sdk/core`
- Remove the `Package.swift` file.
- Create a new `podspec` file in the root of the `prelude-apple-sdk` directory with the following content:

```ruby
Pod::Spec.new do |s|
  s.name           = 'PreludeAppleSDK'
  s.version        = 'X.X.X' # Update this to the version of the SDK
  s.summary        = 'Prelude Apple SDK'
  s.license        = 'Apache-2.0'
  s.author         = 'Prelude <hello@prelude.so> (https://github.com/prelude-so)'
  s.homepage       = 'https://github.com/prelude-so/apple-sdk'
  s.platforms      = { :ios => '15.1' }
  s.swift_version  = '5.4'
  s.source         = { git: 'https://github.com/prelude-so/apple-sdk' }
  s.static_framework = true
  s.vendored_frameworks = 'sdk/core/PreludeCore.xcframework'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_COMPILATION_MODE' => 'wholemodule'
  }
  s.source_files = "**/*.swift", "../sdk/**/*.swift"
end
```

The final directory structure should look like this:

```plaintext
prelude-apple-sdk
├── sdk
│   ├── core
│   │   └── PreludeCore.xcframework
│   └── Sources
│       └── Prelude
│           ├── ...
├── PreludeAppleSDK.podspec
```

Import this `.podspec` file into your project and run normally.

With these steps you should have a working version of the SDK in your project.