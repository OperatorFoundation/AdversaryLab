# The Operator Foundation

[Operator](https://operatorfoundation.org) makes useable tools to help people around the world with censorship, security, and privacy.

## Adversary Lab

Adversary Lab is a service that analyzes captured network traffic to extract statistical properties. Using this analysis, filtering rules can be synthesized to block sampled traffic.

The purpose of Adversary Lab is to give researchers and developers studying network filtering a way to understand how easy it is to block different protocols.
If you have an application that uses a custom protocol, Adversary Lab will demonstrate how a rule can be synthesized to systematically block all traffic using that protocol.
Similarly, if you have a network filtering circumvention tool, then Adversary Lab can synthesize a rule to block your tool.
This analysis can also be used to study tools that specifically attempt to defeat networking filtering, such as Pluggable Transports.

Adversary Lab analysis works by training a classifier on two observed data sets, the "allow" set and the "block" set.
For instance, a simulated adversary could allow HTTP, but block HTTPS. By training the system with HTTP and HTTPS data, it will generate a rule that distinguishes these two classes of traffic based on properties observed in the traffic.

## Getting Started

### Prerequisites

Swift 5.6, included in Xcode 11

## Deployment

To add network traffic to Adversary Lab for analysis you can use [CanaryDesktop](https://github.com/OperatorFoundation/CanaryDesktop.git) for macOS, or [CanaryLinux](https://github.com/OperatorFoundation/CanaryLinux.git) for Linux. When selecting data to load, you should browse to the location of one of the zip files created by Canary. These zip files are named "adversary_data" followed by a timestamp.

## Built With

* [Datable](https://github.com/OperatorFoundation/Datable) - Swift convenience functions to convert between various different types and Data
* [Song](https://github.com/OperatorFoundation/Song.git) - Data structure serialization with static typing.
* [Abacus](https://github.com/OperatorFoundation/Abacus.git) - Swift data structures for data processing.
* [SwiftUICharts](https://github.com/willdale/SwiftUICharts.git) - A charts / plotting library for SwiftUI.
* [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) - ZIP Foundation is a library to create, read and modify ZIP archive files.

## Contributing

Please read CONTRIBUTING.md for details on our code of conduct, and the process for submitting pull requests.

## Versioning

[SemVer](http://semver.org/) is used for versioning. For the versions available, see the [tags on this repository](https://github.com/OperatorFoundation/AdversaryLab/tags).

## Authors

* **Dr. Brandon Wiley** - *Concept and initial work* - [Operator Foundation](https://OperatorFoundation.org/)
* **Adelita Schule** - *Swift implementation* - [Operator Foundation](adelita@OperatorFoundation.org)

## License

This project is licensed under the GPLv3 License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

AdversaryLab is based on Dr. Brandon Wiley's dissertation work, "[Circumventing Network Filtering with Polymorphic Protocol Shapeshifting](http://blanu.net/Dissertation.pdf)".

