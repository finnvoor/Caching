# Caching

```swift
let imageCache = Cache<URL, UIImage> { url in
    let imageData = try! await URLSession.shared.data(from: url).0
    return UIImage(data: imageData)!
}

// Fetched
let (image1, _) = await imageCache.value(for: URL(string: "https://w.wiki/6kXa")!)

// Fetched
let (image2, _) = await imageCache.value(for: URL(string: "https://w.wiki/6kXZ")!)

// Cached
let (image3, _) = await imageCache.value(for: URL(string: "https://w.wiki/6kXa")!)
```
