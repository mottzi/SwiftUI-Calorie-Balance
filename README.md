# Count.kcal

Count.kcal is a calorie balance, body weight and macro-nutrition visualization app that integrates with Apple Health to help users monitor their weight loss or gain over time.

<img width="535" alt="1" src="https://github.com/user-attachments/assets/ebe81322-0781-432c-ac82-599dfff6efa1" />

## Features

- **Caloric Balance**: Monitor calories burned vs. consumed in real-time
- **Midnight Projections**: See your projected caloric balance at midnight
- **Macronutrient**: Track carbs, fats, and protein consumption
- **Body Weight**: Monitor weight changes with weekly and monthly charts
- **Apple Health**: Use Apple Health as data source of define custom energy data in settings
- **Custom Theming**: Choose from multiple color themes for app customization
- **Widget Support**: iOS widgets for home screen at-a-glance information
- **Watch Support**: Watch app, complications and smart-stack support for quick information access

## Caloric Balance

The app tracks two types of balance views:

- **Now Balance**: Shows your current caloric balance (burned - consumed) for the present moment
- **Midnight Balance**: Projects your expected caloric balance at midnight based on your typical passive burn rate

The caloric data is visualized through:

- **Bar Graphs**: Horizontal bars showing the ratio of active burn, passive burn, and consumption
- **Circle Graphs**: Circular progress indicators showing burn and consumption ratios

## Data Sources

Choose between:

- **Apple Health Integration**: Pull data directly from Apple Health
- **Custom Entry**: Manually set your active and passive calorie burns

## Technical Details

- Built with SwiftUI
- HealthKit integration for health data access
- Widget extensions for iOS home screen
- Watch connectivity for syncing data to Apple Watch
- Supports dark and light mode
- Adaptive layout for accessibility

## Privacy

The app requests access to the following HealthKit data:
- Active Energy Burned
- Basal Energy Burned
- Dietary Energy Consumed
- Dietary Protein
- Dietary Fat Total
- Dietary Carbohydrates
- Body Mass
- Step Count

All health data is stored locally and not shared with external servers.

## Testing with health data

In a Debug build, open Settings, scroll to the Debug card at the bottom, and enable **Use Sample Health Data**.
This works on an iPhone or simulator. The choice persists between launches and also applies to
Debug iPhone widgets. The toggle shows whether sample mode is active, and widgets display a test-tube icon while it is on.
Widgets refresh when iOS processes the requested timeline reload.

Sample mode provides 200 days of energy, nutrition, steps, and weight measurements. It does not
read, write, or delete HealthKit records, and it leaves your saved goals and units unchanged.
Sample mode also uses sample burned calories. The energy source picker is read-only while it is active;
your saved Apple Health or Custom Data selection and custom values return when sample mode is off.
The Debug Apple Watch app and complications use the phone's sample mode after settings sync.
Release builds ignore sample mode.

For HealthKit integration checks, turn sample mode off on the simulator and select
**Seed Simulator Health Data**. This saves the same generated dataset into the simulator's
HealthKit store. Turning sample mode on or off does not remove seeded records.
The seeder is never compiled into a physical-device build.

Optional Xcode launch arguments use a common prefix:

| Argument | Effect |
| --- | --- |
| `--health-data-sample` | Enable app-local sample mode and remember the choice. |
| `--health-data-live` | Disable sample mode and remember the choice. |
| `--health-data-seed-simulator` | Disable sample mode and seed simulator HealthKit at launch. |

Use one argument at a time. If combined, sample mode takes priority and suppresses simulator seeding.
These replace `--seed-dashboard-fixture` and `--seed-simulator-health`.

The health data module uses one measured-data interface, `HealthDataSource`, with HealthKit and
sample adapters. `HealthRepository` applies settings, rounding, and energy estimates for both.
The existing models calculate streaks and weight trends from those results. Only the simulator
seeder can save HealthKit samples. Sample mode changes invalidate cached data and discard results
from earlier requests, including when the mode is switched twice during a query.

The Count.kcal scheme includes Swift Testing checks for progress calculations and SQLite persistence.

Run `zsh Tests/run-weight-semantics.sh` for focused checks of the shared weight model.
The runner compiles the production `WeightHistory` and date helpers with query fixtures.
It checks averages, missing days, chart bounds, trends, units, latest measurements, stale-query
rejection, and the phone-to-watch snapshot round trip. Local delivery checks cover kg/lbs parity,
local precedence, deleted readings, older-history supplementation, and refresh failures.

The watch Weight tab reads HealthKit through the same repository and weight calculations as the
phone. It refreshes on activation, calendar-day changes, settings changes, and foreground body-mass
updates. The existing phone snapshot supplements calendar days before HealthKit's reported watch
access boundary. It cannot replace recent local days or restore a deleted recent reading. Without
a phone snapshot, local weight still displays; a period containing inaccessible days shows
"Limited history". Failed refreshes preserve the previous result and show an error; the first failed
read can use a cached phone snapshot.

Weekly and Monthly averages and charts appear together on one scrollable page. The charts use
the available width without cards or period controls. Each section leads with a large average;
the latest measurement and its date appear in a compact footer. The monthly chart preserves the
phone's Monday-aligned series, while its average uses the last 30 days with recorded weights.
The watch chart ends at the last daily entry rather than reserving space for the phone chart's
empty future days. An older phone supplement shows its capture date. Independent device reads
share calculation semantics; their values can differ while HealthKit synchronization is pending.

The iPhone Progress card retains the weight charts and adds two completed-period summaries.
Average deficit uses the last 7 or 30 completed calendar days, excluding today. Missing food or
measured resting energy excludes a day automatically; zero active energy is valid. Custom mode
uses the current configured daily burn, as before. A surplus contributes a negative deficit.
At least two included days are required. Weight change compares unrounded daily means with the
previous consecutive period, with at least two measured days in each period. Calorie exclusions
do not remove weights, change daily Health readings, or affect streaks.

The Calories heading offers retrospective day choices. Manual exclusion and fasting confirmation
remain saved until the user changes them. Food arriving after a fasting confirmation excludes the
day as a conflict; it never silently overrides the choice. The coverage row opens the calculation
explanation and day list. Automatic exclusions can resolve when missing readings arrive.

SQLiteData 1.12.0 stores only explicit choices in the iPhone App Group's Application Support folder,
with a versioned migration and file protection. Sample-mode choices use a separate record namespace.
Database failures do not erase records or substitute an empty database. Resolved dependency versions
are checked in for reproducible builds. CloudKit sync is deferred. Widgets and Watch keep their current
read-only Health displays and do not consume these iPhone-only summary choices yet.

## Watch energy contour

Energy contour gives the large rectangular slot to today's intake and expenditure.
The intake line steps at the end of each recorded fifteen-minute interval. The burn
curve passes through cumulative interval totals. A light fill shows their separation,
and a marker locates the present. Dashed continuations distinguish estimates
from recorded energy; the intake continuation holds the current total fixed.

The main value shows estimated food allowance remaining after the saved loss or gain
goal. The midnight burn policy matches the dashboard: recorded active energy plus
the greater of recorded resting energy and the prior seven-day resting average.
Custom burn settings produce a dashed estimated curve throughout. The drawing uses
the saved colors and kcal or kJ unit. Tinted faces keep burn accented and intake white.

The gallery has a repeatable afternoon example. Debug sample mode supplies a meal and
activity history without writing HealthKit data. For simulator verification only,
the shared `debugEnergyContourSampleHour` key fixes that complication's sample time
to a decimal hour. This key has no effect in Release builds or with sample mode off.

Run `zsh Tests/run-energy-contour.sh` for interval accumulation, allowance, custom
estimates, missing readings, and calendar-day bounds including daylight saving.

## Watch goal complications

The 17 balance complications cover Now and Midnight through corner text and gauges,
circular gauges and graphs, and rectangular circles and bars. Three goal complications
add nutrition and movement to that set. Each supports rectangular and circular slots.

- **Calorie room** shows the estimated daily food allowance minus recorded intake.
  The allowance uses the existing midnight burn estimate, subtracting the balance goal
  for weight loss or adding it for weight gain. Its segmented meter shows intake against
  that allowance. Amounts use the saved kcal or kJ unit. An exceeded allowance shows
  the amount over budget; missing burn data shows no estimate.
- **Macro goals** shows three labeled progress rings for protein, carbs, and fats,
  including recorded grams and saved goals. The circular version focuses on protein.
- **Step goal** shows today's count, a progress arc, and remaining steps. Reaching
  the saved goal replaces the walking figure with a checkmark. Counts keep increasing
  after the arc fills. An unset goal displays the count without claiming completion.

The complications use the shared health repository and the existing fifteen-minute or midnight
refresh request. Goals and units are captured before each query; a settings change during
the query discards that result and starts another read. Gallery examples use fixed
values; installed complications use HealthKit or the existing Debug sample-data mode.
Track and progress use separate accent groups so the diagrams also work on tinted faces.

Run `zsh Tests/run-complication-goals.sh` for the allowance and goal calculations.
The checks cover loss and gain, overspending, missing goals, completed and exceeded goals,
empty readings, and data already expressed in kilojoules.
