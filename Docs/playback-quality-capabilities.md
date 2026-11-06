# Playback quality and audio: step 1

The joint desktop/Mobile Enhanced capability audit is maintained in
[NuvioDesktop's capability report](../../NuvioDesktop/docs/playback-quality-capabilities.md)
in the sibling checkout. It covers Mobile Enhanced revision `313ca3d1` and desktop
revision `fad3cf3e`, with source inspection on 2026-10-28.

Mobile findings:

- Android Auto starts with ExoPlayer and can fall back to libmpv. iOS uses libmpv.
- The current HLS resolver selects a single-variant temporary playlist even for
  Auto; it does not combine alternative addon sources, measure bandwidth or
  verify device codec capabilities.
- ExoPlayer receives bandwidth estimates, but only logs them. Its native adaptive
  HLS/DASH path is a candidate requiring integration and runtime validation.
- Both mpv integrations require controlled reloads for the proposed quality
  switches until a seamless path is separately demonstrated.
- Audio selection already exists; server audio can restart playback. Track role,
  codec and channel metadata need structured support for reliable deduplication.

Step 1 changes documentation only. No seamless path has been runtime-certified
and no automatic adaptation has been newly enabled. See the joint report for
the full matrix, code evidence, integration decisions and verification gates.
