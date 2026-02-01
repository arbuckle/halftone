# Halftone Effect: Technical Documentation

This document describes the halftone rendering approach used in this application, based on traditional photomechanical printing techniques.

## The Fundamental Principle

Halftone is an **optical illusion**. Traditional printing methods (letterpress, offset lithography) can only apply ink or leave paper blank—there are no intermediate tones. The halftone process creates the appearance of continuous tone by varying the **size** of printed dots:

```
Dark area (80%):        Midtone (50%):         Light area (20%):
  ████████                ●●●●●●●●                ·  ·  ·  ·
  ████████                ●●●●●●●●              ·  ·  ·  ·
  ████████                ●●●●●●●●                ·  ·  ·  ·
  (large dots)            (medium dots)           (tiny dots)
```

When viewed from a normal reading distance, the eye blends these dots with the surrounding white paper, perceiving smooth gradations of tone.

## Tonal Regions

Traditional halftone defines three density regions:

| Region | Density | Dot Behavior | Visual Result |
|--------|---------|--------------|---------------|
| **Dmin** (highlights) | 0-10% | Tiny or no dots | Nearly white, paper dominates |
| **Dmid** (midtones) | 10-90% | Variable dot sizes | Visible texture, tonal gradation |
| **Dmax** (shadows) | 90-100% | Large dots nearly touching | Nearly solid, minimal paper visible |

### Highlight Threshold

A critical aspect of authentic halftone is that **highlights have no dots**. In real printing, areas below ~8-10% density simply don't receive ink—the paper shows through completely.

Our implementation enforces this with a highlight threshold:

```metal
constant float kHighlightThreshold = 0.08;

if (channelValue < kHighlightThreshold) {
    return 0.0;  // No dot - white paper
}
```

This prevents the "uniform moiré" problem where modern UIs with subtle grays (5-20% density) all produce similar small dots that look like noise.

## CMYK Color Separation

Color halftone uses four ink channels:

| Channel | Color | Angle | Purpose |
|---------|-------|-------|---------|
| C | Cyan | 15° | Subtracts red from white light |
| M | Magenta | 75° | Subtracts green from white light |
| Y | Yellow | 0° | Subtracts blue from white light |
| K | Black | 45° | Adds density and contrast |

### Why Black (K)?

> "The optical properties of real color pigments used for color photomechanical printing did not produce a good black color."
> — Getty Halftone Atlas

CMY inks alone produce a muddy brown, not true black. The K channel provides:
- True black tones
- Better shadow detail
- Reduced ink usage (GCR/UCR techniques)
- Sharper text rendering

### Screen Angles

Each color channel is printed at a different angle to minimize moiré interference patterns:

```
Cyan (15°):     Magenta (75°):    Yellow (0°):     Black (45°):
   / / /           \ \ \            — — —            \ \ \
  / / /             \ \ \           — — —             \ \ \
 / / /               \ \ \          — — —              \ \ \
```

The 30° separation between CMY channels and the 45° black angle are industry standards derived from decades of printing experience.

## Dot Size Calculation

Dot radius scales with the square root of the ink density:

```metal
float dotRadius = maxRadius * sqrt(channelValue);
```

The square root provides **perceptually linear** scaling. This is because perceived coverage relates to dot area (πr²), not radius. Using sqrt(density) ensures that 50% density produces dots covering approximately 50% of the cell area.

### Dot Sizing Examples

| Density | sqrt(density) | Relative Radius | Area Coverage |
|---------|---------------|-----------------|---------------|
| 10% | 0.316 | 31.6% | ~10% |
| 25% | 0.500 | 50.0% | ~25% |
| 50% | 0.707 | 70.7% | ~50% |
| 75% | 0.866 | 86.6% | ~75% |
| 100% | 1.000 | 100% | ~100% |

## Letterpress Halo Effect

Traditional letterpress printing has a distinctive appearance: ink pushed outward under high pressure creates a **dark halo around each dot** with a **slightly lighter center**.

Our implementation simulates this:

```metal
// Distance from center, normalized to dot radius
float centerDist = dist / max(dotRadius, 0.001);

// Halo: darker at edges (0.3-0.9 of radius), 25% intensity boost
float halo = smoothstep(0.3, 0.9, centerDist) * 0.25;

return edge * (1.0 + halo);
```

This creates dots that are subtly darker at their perimeter, mimicking authentic letterpress printing.

## Screen Resolution (LPI)

Traditional halftone uses lines-per-inch (LPI) to measure screen frequency:

| Application | LPI | Dot Size | Viewing Distance |
|-------------|-----|----------|------------------|
| Newspaper | 50-85 | Large, visible | Arm's length |
| Magazine | 133-150 | Medium | ~30cm |
| Fine art books | 175-300 | Small, barely visible | Close inspection |

Our "Fine/Medium/Coarse" presets correspond to different effective LPI values, with larger dots being more visible and creating a more pronounced halftone aesthetic.

## Black-Only Mode

For a cleaner "newspaper" aesthetic, the application offers a black-only mode that uses only the K channel:

```metal
if (uniforms.useBlackOnly != 0) {
    // Convert to grayscale using luminance weights
    float gray = dot(screenColor.rgb, float3(0.299, 0.587, 0.114));
    float k = 1.0 - gray;  // Darkness value

    float kHalftone = halftoneChannel(pixelPos, k, uniforms.dotSize, kBlackAngle);
    halftoneRgb = float3(1.0 - kHalftone);  // White minus black
}
```

Benefits:
- No color moiré from overlapping CMY grids
- Cleaner, more graphic appearance
- Authentic newspaper/comic book aesthetic
- Reduced visual complexity

## Anti-Aliasing

Dot edges use smoothstep for anti-aliasing:

```metal
float edge = smoothstep(dotRadius + 0.5, dotRadius - 0.5, dist);
```

This creates a 1-pixel soft transition at dot boundaries, preventing harsh aliasing artifacts while maintaining crisp dot definition.

## Coordinate Transformation

For each color channel, pixel coordinates are rotated to the channel's screen angle:

```metal
float2 rotatePoint(float2 p, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return float2(p.x * c - p.y * s, p.x * s + p.y * c);
}
```

The rotated coordinates are then quantized to a grid to find the nearest dot center:

```metal
float2 cellPos = floor(rotatedPos / dotSize + 0.5) * dotSize;
```

## References

- Getty Research Institute. "The Halftone Atlas." Conservation documentation.
- Adams, Faux, Rieber. "Printing Technology." Delmar, 5th edition.
- Southworth, Miles. "Color Separation Techniques." Graphic Arts Publishing.
