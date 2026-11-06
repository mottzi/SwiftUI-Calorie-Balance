# Share full streaks with separate consent

Goal-sharing and icon-setting semantics are updated by [ADR 0005](0005-separate-goal-sharing-from-local-icon-settings.md).

A full streak can reveal goal achievement beyond the six completed days covered by History, so Streak is an independent, mutual sharing scope. Existing connections keep their grants; adding Streak requires a new proposal and acceptance rather than silently expanding Today or History.

The sender calculates the count with the dashboard's goal and excluded-day rules. Its current-day record uses the existing encrypted snapshot hierarchy with empty calorie values, an optional count, and the sender's flame color. Calorie-scope records omit the count, and Streak records omit calorie values, projections, goal results, and exclusions. A missing count clears an earlier count when goal status is hidden. The summary expires at sender midnight.
