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
The Apple Watch app and complications continue to use HealthKit. Release builds ignore sample mode.

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

Run the health data tests with the Count.kcal scheme's Test action on an iPhone simulator.
