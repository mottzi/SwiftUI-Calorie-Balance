# Count.kcal

Count.kcal is a calorie balance, body weight and macro-nutrition visualization app that integrates with Apple Health to help users monitor their weight loss or gain over time.

- Landing Page: https://count.mottzi.de/
- App Store Page: https://apps.apple.com/us/app/calorie-deficit-tracker/id6476797015

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
