# Session interruptions design

F9 extends the existing concrete MediaSession/BroadcastSession owners. A direct main-actor interruption callback cancels startup and reconnect work before media closes, retains the pending remote identity and marks remote completion unknown. It never sends End because iOS may suspend background work. Foreground performs bounded reads only; camera reopening and resume publication each require operator action.

Explicit resume reads the journal's same channel/event and binding, requires a freshly reopened preview, and presents a new confirmation. It creates a new local recording/timeline, validates the dedicated inactive bound stream, and publishes only after writer admission. A live event is observed, never transitioned live again. Ambiguous mutations must first reconcile; unknown complete mutations cannot resume. Optional nonsecret stream/profile fields preserve the admitted context across relaunch, while older journals remain readable and conservatively require reconciliation/Studio resolution.

Alternatives considered: extending automatic F8 reconnect across background would publish without fresh operator intent; always requiring End/new event would abandon eligible existing live events. The explicit same-event path preserves the required boundary with no new capture/encoder or generic observer framework.

Serious heat reduces raster cadence without profile changes. Critical heat, capture/encoder failure, microphone route loss and camera/audio/background interruptions stop both outputs. File-consumer failures preserve healthy upload; finalization failures maintain a persistent backup warning. Exhausted background time marks retained metadata incomplete and restores idle-timer ownership; it never promises playback or remote completion.

Validation uses deterministic fixture state/late-result and injected writer-failure tests, native Simulator builds, and independent actual-file review. Real lock/Home/audio, idle-timer restoration, thermal measurements and receiver/file continuity remain physical acceptance work; no phone or live service is used in this stage.
