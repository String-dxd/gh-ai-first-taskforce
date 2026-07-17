# Flow checks

Apply only to multi-step interactions — scenarios where Step 3 identified the surface as a new page or flow (not a modification).

- A non-destructive exit exists at every step; in-progress work is preserved or explicitly discarded on interruption — never silently lost
- Every async state change has a loading, success, and error state
- Keyboard traversal works across the whole journey, not just within each screen
- Focus lands somewhere sensible after every step change
