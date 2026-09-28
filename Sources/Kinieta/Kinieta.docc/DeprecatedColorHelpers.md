# Replacing the deprecated colour helpers

Kinieta 1.x shipped a set of public `UIColor` helpers it never meant to export.
They are deprecated and will be removed in 2.0.

## Overview

The helpers were vendored from HandyUIKit for internal colour conversion. They
leaked into every app that imports Kinieta, and apps that also use HandyUIKit
got ambiguity errors. Kinieta now does its colour arithmetic internally and
only uses these helpers to keep existing code compiling.

| Deprecated | Replacement |
| --- | --- |
| `color.rgba` | `color.getRed(_:green:blue:alpha:)` |
| `color.hsba` | `color.getHue(_:saturation:brightness:alpha:)` |
| `color.hlca`, `UIColor(hue:luminance:chroma:alpha:)` | HandyUIKit |
| `color.change(_:by:)`, `color.change(_:to:)`, `ChangeableColorComponent` | HandyUIKit |
| `color.change(.alpha, to: a)` | `color.withAlphaComponent(a)` |
| `UIColor.Components` | None. It had no public members. |

To choose how Kinieta itself interpolates colours, use ``ColorInterpolation``.
