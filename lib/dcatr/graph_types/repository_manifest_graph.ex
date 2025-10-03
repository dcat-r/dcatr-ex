defmodule DCATR.RepositoryManifestGraph do
  @moduledoc """
  A `DCATR.ManifestGraph` containing the DCAT catalog description of a `DCATR.Repository`.

  Repository manifest graphs contain the DCAT descriptions of the repository itself,
  including metadata about the dataset and all graphs. This manifest is part of the
  repository distribution and shared across all service instances.

  This graph exhibits controlled self-reference - it describes the repository of
  which it is part. The graph MUST have its own URI distinct from the repository
  URI to avoid identifier collision, e.g.:

  - `{repository-uri}/manifest`
  - `{repository-uri}/metadata`
  """

  use Grax.Schema

  schema DCATR.RepositoryManifestGraph < DCATR.ManifestGraph do
  end
end
