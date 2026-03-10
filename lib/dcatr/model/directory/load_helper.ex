defmodule DCATR.Directory.LoadHelper do
  @moduledoc false

  # Shared utilities for on_load normalization across Directory-related schemas.
  #
  # Bridges the gap between the generic dcatr:member property and its type-specific
  # sub-properties (dcatr:dataGraph, dcatr:repositorySystemGraph, etc.) that Grax
  # cannot resolve without RDFS sub-property reasoning.

  alias Grax.Schema.CardinalityError

  @member_property DCATR.member()

  # Sub-properties pointing to container types (not Grax subtypes of DCATR.Element)
  @directory_sub_properties [
    DCATR.directory(),
    DCATR.repositoryDataset()
  ]

  # Sub-properties pointing to graph types (Grax subtypes of DCATR.Element)
  @graph_sub_properties [
    DCATR.dataGraph(),
    DCATR.repositoryDataGraph(),
    DCATR.repositorySystemGraph(),
    DCATR.repositoryManifestGraph(),
    DCATR.serviceManifestGraph(),
    DCATR.serviceWorkingGraph(),
    DCATR.serviceSystemGraph()
  ]

  @sub_properties @directory_sub_properties ++ @graph_sub_properties

  @doc """
  Normalizes members from `dcatr:member` that Grax couldn't map to typed fields.

  Since `dcatr:member` is not mapped in Dataset/Repository/ServiceData schemas, Grax
  stores it in `__additional_statements__`. We read from there and filter out IDs
  already loaded into typed fields to avoid duplicates.

  The `dispatcher` function receives `(loaded_member, accumulator)` and must return
  `{:ok, updated_accumulator}` or `{:error, reason}`.
  """
  def normalize_members(struct, graph, dispatcher) do
    already_loaded = collect_loaded_ids(struct)

    struct
    |> member_objects()
    |> Enum.reject(&MapSet.member?(already_loaded, &1))
    # we reverse here so that dispatcher functions can do faster prepends of elements the respective fields
    |> Enum.reverse()
    |> Enum.reduce_while({:ok, struct}, fn member_id, {:ok, acc} ->
      case Grax.load(graph, member_id) do
        {:ok, member} ->
          case dispatcher.(member, acc) do
            {:ok, acc} -> {:cont, {:ok, acc}}
            {:error, _} = error -> {:halt, error}
          end

        {:error, error} ->
          {:halt, {:error, error}}
      end
    end)
  end

  @doc """
  Assigns a member to a singular (cardinality-1) field, returning an error if
  the field already holds a different value.
  """
  def assign_singular(acc, field, %{__id__: member_id} = member) do
    case Map.get(acc, field) do
      nil -> {:ok, Map.put(acc, field, member)}
      %{__id__: ^member_id} -> {:ok, acc}
      existing -> {:error, CardinalityError.exception(cardinality: 1, value: [existing, member])}
    end
  end

  defp collect_loaded_ids(struct) do
    struct
    |> Map.from_struct()
    |> Map.drop([:__id__, :__additional_statements__])
    |> Map.values()
    |> List.flatten()
    |> Enum.filter(&Grax.Schema.struct?/1)
    |> MapSet.new(& &1.__id__)
  end

  defp member_objects(%{__additional_statements__: additional}) do
    additional |> Map.get(@member_property, %{}) |> Map.keys()
  end

  @doc """
  Normalizes members from sub-properties that Grax couldn't map to `dcatr:member`.

  For `DCATR.Directory` schemas: finds objects linked via type-specific sub-properties
  not already present in `members`, loads them, and appends to the members list.

  Directory sub-properties (dcatr:directory, dcatr:repositoryDataset) are loaded as
  `DCATR.Directory`, since their target types (e.g. `DCATR.Dataset`) are not Grax
  subtypes of `DCATR.Element`. Graph sub-properties are loaded polymorphically,
  since their target types already inherit from `DCATR.Element` at the Grax level.
  """
  def normalize_from_sub_properties(directory, graph) do
    description = RDF.Graph.description(graph, directory.__id__)
    already_loaded = MapSet.new(directory.members, & &1.__id__)

    description
    |> RDF.Description.take(@sub_properties)
    |> RDF.Data.reduce_while({:ok, directory}, fn {_, property, member_id}, {:ok, acc} ->
      if member_id in already_loaded do
        {:cont, {:ok, acc}}
      else
        if property in @directory_sub_properties do
          DCATR.Directory.load(graph, member_id)
        else
          Grax.load(graph, member_id)
        end
        |> case do
          {:ok, member} -> {:cont, {:ok, %{acc | members: [member | acc.members]}}}
          {:error, error} -> {:halt, {:error, error}}
        end
      end
    end)
  end
end
