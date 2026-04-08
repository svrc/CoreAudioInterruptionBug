This visionOS app demonstrates that when you dismiss an immersive space temporarily to view passthrough, and resume it, visionOS silently kills the underlying CoreAudio session without throwing an error.

Workaround is to run a heartbeat probe on the Core Audio session and to restart it if it does.  
