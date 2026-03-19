<p align="center">
  <img src="dcatr-logo.png" alt="DCAT-R Logo" width="100" align="right">
</p>

# DCAT-R.ex

[![Hex.pm](https://img.shields.io/hexpm/v/dcatr.svg?style=flat-square)](https://hex.pm/packages/dcatr)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/dcatr/)
[![License](https://img.shields.io/hexpm/l/dcatr.svg)](https://github.com/dcat-r/dcatr-ex/blob/main/LICENSE.md)

[![ExUnit Tests](https://github.com/dcat-r/dcatr-ex/actions/workflows/elixir-build-and-test.yml/badge.svg)](https://github.com/dcat-r/dcatr-ex/actions/workflows/elixir-build-and-test.yml)
[![Dialyzer](https://github.com/dcat-r/dcatr-ex/actions/workflows/elixir-dialyzer.yml/badge.svg)](https://github.com/dcat-r/dcatr-ex/actions/workflows/elixir-dialyzer.yml)
[![Quality Checks](https://github.com/dcat-r/dcatr-ex/actions/workflows/elixir-quality-checks.yml/badge.svg)](https://github.com/dcat-r/dcatr-ex/actions/workflows/elixir-quality-checks.yml)

**A framework for building data services over RDF repositories**

DCAT-R.ex is an Elixir library implementing the [DCAT-R vocabulary](https://w3id.org/dcatr) - an OWL extension of [DCAT 3](https://www.w3.org/TR/vocab-dcat-3/) for describing and operating RDF repositories. It provides Grax schemas, a manifest-based configuration system, and extension points for building specialized services over RDF datasets.


## What is DCAT-R?

[DCAT-R](https://w3id.org/dcatr) (DCAT for RDF Repositories) extends DCAT 3 with vocabulary for the internal structure of services that operate over RDF datasets. It organizes repositories through a **four-level hierarchy**:

```
Service                  (what you can do - operations layer)
 └── Repository          (what you have - distributable data bundle)
      └── Dataset        (user data - catalog of graphs)
           └── Graph     (individual RDF graphs)
```

Every graph belongs to exactly one of four disjoint types:

- **DataGraph** - user data forming the dataset content
- **ManifestGraph** - DCAT-R configuration and catalog metadata
- **SystemGraph** - application-specific operational data (history, provenance, indexes)
- **WorkingGraph** - temporary, service-local working areas

DCAT-R provides the structural vocabulary; applications extend it by defining specialized service types with domain-specific operations and SystemGraphs.

For the full specification, see the [DCAT-R specification](https://w3id.org/dcatr).


## Getting Started

### Installation

Add `dcatr` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:dcatr, "~> 0.1"}
  ]
end
```

### Further Reading

**For detailed API documentation**, including complete explanations of core concepts (Service, Repository, Dataset, Graph types, SystemGraphs, Manifests), see the [HexDocs documentation](https://hexdocs.pm/dcatr).

**For the formal vocabulary specification** (RDF/OWL definitions, properties, constraints), see the [DCAT-R specification](https://w3id.org/dcatr).

**For Elixir developers building service types**, start with the module documentation for:
- `DCATR` - Overview and core concepts
- `DCATR.Service.Type` - Behaviour for defining custom services
- `DCATR.Repository.Type` - Behaviour for extending repositories with custom SystemGraphs
- `DCATR.Manifest` - Configuration and loading system


## Consulting

If you need help with your Elixir and Linked Data projects, just contact [NinjaConcept](https://www.ninjaconcept.com/) via <contact@ninjaconcept.com>.


## Acknowledgements

<table style="border: 0;">
<tr>
<td><a href="https://nlnet.nl/"><img src="https://nlnet.nl/logo/banner.svg" alt="NLnet Foundation Logo" height="100"></a></td>  
<td><a href="https://nlnet.nl/core" ><img src="https://nlnet.nl/logo/NGI/NGIZero-green.hex.svg" alt="NGI Zero Core Logo" height="150"></a></td>  
<td><a href="https://jb.gg/OpenSource"><img src="https://resources.jetbrains.com/storage/products/company/brand/logos/jetbrains.svg" alt="JetBrains Logo" width="150"></a></td>
</tr>  
</table>  

This project is funded through [NGI Zero Core](https://nlnet.nl/core), a fund established by [NLnet](https://nlnet.nl/) with financial support from the European Commission's [Next Generation Internet](https://ngi.eu/) program.

[JetBrains](https://jb.gg/OpenSource) supports the project with complimentary access to its development environments.


## License and Copyright

(c) 2026 Marcel Otto. MIT Licensed, see [LICENSE](LICENSE.md) for details.
