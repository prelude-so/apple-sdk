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