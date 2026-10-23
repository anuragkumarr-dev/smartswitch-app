# Command Lifecycle State Diagram

This document specifies the end-to-end lifecycle of a switching command in SmartSwitch (Blueprint §3.2 & §3.3).

## Key Guarantees
1. **Zero-Latency Perceived Feedback**: Optimistic pending state is committed in the exact same frame as the user tap ($< 16\text{ ms}$).
2. **Dual-Path Local-First Routing**: Local WebSocket (800 ms timeout) $\rightarrow$ Cloud MQTT fallback (4 s timeout).
3. **Idempotency**: Every command carries a unique `commandId`. The Root switch de-duplicates commands, ensuring no double execution if both paths deliver the message.
4. **Monotonic Version Reconciliation**: Monotonically increasing version counter (`ver`). Lower versions are ignored, ensuring convergence across multiple phones.
5. **Deterministic Rollback**: If neither local nor cloud can confirm delivery within their timeouts, the UI cleanly rolls back to the last confirmed reported state.

---

## Mermaid State Diagram

```mermaid
stateDiagram-v2
    [*] --> Idle: Device rendered with confirmed state (ver = N)

    state "User Interaction" as UI {
        Idle --> Pending: User Taps Switch (Frame 0)
        note right of Pending
            Optimistic update committed in same frame.
            pendingGangStates[gangId] = desired
            pendingCommandId = c-xxxx
            Toggle animates & haptic fires.
        end note
    }

    state "Dual-Path Command Routing" as Routing {
        Pending --> RouteChoice: CommandRouter.send(gatewayId, envelope)

        RouteChoice --> LocalPath: Local gateway reachable (Heartbeat <= 5s)
        RouteChoice --> CloudPath: Local gateway unreachable

        state LocalPath {
            [*] --> LocalSend: WebSocket send (AES-256-GCM)
            LocalSend --> LocalWaitAck: Awaiting ACK (800 ms timeout)
            LocalWaitAck --> LocalAckSuccess: ACK received (ver = N+1)
            LocalWaitAck --> LocalTimeout: 800 ms elapsed without ACK
        }

        LocalTimeout --> CloudPath: Fallback to Cloud MQTT (WSS/TLS)

        state CloudPath {
            [*] --> CloudSend: Publish to home/{id}/dev/{id}/cmd
            CloudSend --> CloudWaitAck: Awaiting ACK / state update (4 s timeout)
            CloudWaitAck --> CloudAckSuccess: ACK / state received (ver >= N+1)
            CloudWaitAck --> CloudTimeout: 4 s elapsed without ACK
        }
    }

    LocalAckSuccess --> Confirmed: Clear pending, commit reported state & ver
    CloudAckSuccess --> Confirmed: Clear pending, commit reported state & ver

    CloudTimeout --> Rollback: Both paths failed / unreachable
    RouteChoice --> Rollback: Neither local nor cloud connected

    state Confirmed {
        [*] --> PersistDB: Save shadow & ver to SQLite (drift)
        PersistDB --> EmitLiveDeltas: Fan out to other phones & Riverpod state
        EmitLiveDeltas --> Idle: Stable confirmed state (ver = N+1)
    }

    state Rollback {
        [*] --> RevertState: Clear pendingGangStates
        RevertState --> ShowErrorToast: Revert to confirmed reported state + show error snackbar
        ShowErrorToast --> Idle: Restored to verified physical state
    }
```

---

## Conflict Resolution & Multi-Phone Convergence
When two phones ($Phone_A$ and $Phone_B$) toggle the same switch concurrently:
1. Both send absolute commands (`set gang1 on` vs `set gang1 off`) with unique `commandId`s.
2. The Root switch serializes commands sequentially:
   - Command 1 executes $\rightarrow$ reports $ver = 101$.
   - Command 2 executes $\rightarrow$ reports $ver = 102$.
3. Both phones receive the stream of state reports:
   - When report with $ver = 102$ arrives, both phones accept it because $102 > 101$.
   - Any delayed report with $ver \le 101$ is dropped by `DeviceRepository` and `DevicesNotifier`.
4. Both phones converge deterministically to the identical confirmed state.
