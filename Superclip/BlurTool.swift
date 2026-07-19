//
//  BlurTool.swift
//  Superclip
//

import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum BlurTool {
  private static let ciContext = CIContext()

  /// Apply blur to a rectangular region of an image.
  /// - Parameters:
  ///   - image: Source NSImage
  ///   - rect: Region in image pixel coordinates to blur
  ///   - style: Gaussian or pixelate
  ///   - radius: Blur radius (points for gaussian, pixel size for pixelate)
  /// - Returns: New image with the specified region blurred
  static func applyBlur(
    to image: NSImage,
    in rect: CGRect,
    style: BlurStyle,
    radius: CGFloat
  ) -> NSImage? {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
      return nil
    }

    let ciImage = CIImage(cgImage: cgImage)
    let imageExtent = ciImage.extent

    // Flip rect from top-left origin to CIImage bottom-left origin
    let flippedRect = CGRect(
      x: rect.origin.x,
      y: imageExtent.height - rect.origin.y - rect.height,
      width: rect.width,
      height: rect.height
    ).intersection(imageExtent)

    guard !flippedRect.isEmpty else { return image }

    let blurred: CIImage?
    switch style {
    case .gaussian:
      let filter = CIFilter.gaussianBlur()
      filter.inputImage = ciImage
      filter.radius = Float(radius)
      blurred = filter.outputImage
    case .pixelate:
      let filter = CIFilter.pixellate()
      filter.inputImage = ciImage
      filter.scale = Float(max(radius, 2))
      filter.center = CGPoint(x: flippedRect.midX, y: flippedRect.midY)
      blurred = filter.outputImage
    }

    guard let blurredImage = blurred else { return image }

    // Crop the blurred version to just the region, then composite over original
    let croppedBlur = blurredImage.cropped(to: flippedRect)
    let composited = croppedBlur.composited(over: ciImage)

    guard let outputCG = ciContext.createCGImage(composited, from: imageExtent) else {
      return image
    }

    return NSImage(
      cgImage: outputCG,
      size: NSSize(width: cgImage.width, height: cgImage.height)
    )
  }

  /// Pre-compute a fully blurred copy of the entire image for live preview.
  static func precomputeBlurred(
    image: NSImage,
    style: BlurStyle,
    radius: CGFloat
  ) -> NSImage? {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
      return nil
    }

    let ciImage = CIImage(cgImage: cgImage)

    let blurred: CIImage?
    switch style {
    case .gaussian:
      let filter = CIFilter.gaussianBlur()
      filter.inputImage = ciImage
      filter.radius = Float(radius)
      blurred = filter.outputImage
    case .pixelate:
      let filter = CIFilter.pixellate()
      filter.inputImage = ciImage
      filter.scale = Float(max(radius, 2))
      blurred = filter.outputImage
    }

    guard let blurredOutput = blurred else { return nil }
    // Clamp to extent to avoid edge artifacts from gaussian blur
    let clamped = blurredOutput.cropped(to: ciImage.extent)
    guard let outputCG = ciContext.createCGImage(clamped, from: ciImage.extent) else {
      return nil
    }

    return NSImage(
      cgImage: outputCG,
      size: NSSize(width: cgImage.width, height: cgImage.height)
    )
  }
}
