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

Swift 5.0, included in Xcode 11

Install and run Redis.

You can install it with Homebrew

```
brew install redis
brew services start redis
```

Or refer to the [Redis documentation](https://redis.io/download) to install it manually.

### Installing

Check out the project from Github

```
git clone https://github.com/OperatorFoundation/AdversaryLab
cd AdversaryLab
```

Install the Swift Package used by the graphical interface. Swift packages are now handled in xcode. There is no longer a sub-project for updating packages via command line.

Add the following executables to the AdversaryLab/Executables/ folder: redis-cli, redis-server, and [AdversaryLabClient](https://github.com/OperatorFoundation/AdversaryLabClientSwift). Please note that this project requires the Swift version of the client, it is no longer compatible with the Go version.


## Deployment

Open the Xcode project. Once you have addressed signing as needed, and Xcode has downloaded the dependencies (packages), you can click the Run button to run the Adversary Lab graphical interface.

To add network traffic to Adversary Lab for analysis, you need the AdversaryLabClient command line tool. For the [installation
instructions](https://github.com/OperatorFoundation/AdversaryLabClientSwift) to install and use the command line tool.

## Built With

* [Auburn](https://github.com/OperatorFoundation/Auburn) - An idiomatic Swift library for using Redis
* [RedShot](https://github.com/OperatorFoundation/Redshot) - Lightweight Redis client for Swift
* [Datable](https://github.com/OperatorFoundation/Datable) - Swift convenience functions to convert between various different types and Data
* [Redis](https://redis.io/) - A fast database with support for data structures

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

