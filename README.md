# Sky Image Inspector — Ruby

A small dependency-free Ruby CLI for bounded metadata inspection of PNG, JPEG, and GIF files. The historical repository name is retained, but the implemented product is an **image inspector and optimization-advice primitive**, not an image recompressor.

## Implemented behavior

- Detect PNG, JPEG, and GIF by binary structure rather than filename extension.
- Extract validated width and height from supported formats.
- Reject empty, malformed, unsupported, non-file, or oversized inputs.
- Enforce a 32 MiB file-size ceiling.
- Produce SHA-256 content identity.
- Emit deterministic size/dimension-based optimization recommendations.
- Read files only; the tool does not modify source images.

```bash
ruby bin/sky_image ./photo.jpg
```

## Verification

The CI gate runs Ruby syntax checks, Minitest coverage for PNG/GIF/JPEG and invalid files, a real CLI smoke fixture, Docker build, non-root UID verification, and a containerized read-only-volume smoke test.

## Product boundary

This repository does **not** currently recompress, resize, transcode, strip metadata, repair, render, or rewrite images. It does not include libvips/ImageMagick codecs, AVIF/WebP encoders, EXIF parsing, animated-image analysis, malware scanning, content moderation, image recognition, cloud storage, a web API, queues, tenant isolation, or production deployment.

Optimization recommendations are heuristics based only on dimensions, byte size, and format. They are not proof that a smaller representation can be generated without unacceptable quality loss. A future optimizer should introduce a real, tested codec backend and compare output size/quality before the repository makes compression claims.
