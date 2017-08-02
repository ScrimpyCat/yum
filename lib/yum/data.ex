defmodule Yum.Data do
    @moduledoc """
      Import food data.
    """
    @type translation :: %{ optional(String.t) => translation | String.t }
    @type translation_tree :: %{ optional(String.t) => translation }
    @type diet_list :: [String.t]
    @type allergen_list :: [String.t]
    @type nutrition :: %{ optional(String.t) => any }
    @type food_list :: %{ optional(String.t) => translation_tree }
    @type ingredient_info :: %{ optional(String.t) => translation_tree | diet_list | allergen_list | nutrition }
    @type cuisine_info :: %{ optional(String.t) => translation_tree | food_list }
    @type ingredient_tree :: %{ optional(String.t) => ingredient_tree, required(:__info__) => ingredient_info }
    @type cuisine_tree :: %{ optional(String.t) => cuisine_tree, required(:__info__) => cuisine_info }
    @type diet_tree :: %{ optional(String.t) => translation_tree }
    @type allergen_tree :: %{ optional(String.t) => translation_tree }

    defp load(path), do: TomlElixir.parse_file!(path)

    @path "data/Food-Data"

    @doc """
      Load the diet names and translations.
    """
    @spec diets(String.t) :: diet_tree
    def diets(data \\ @path), do: load(Path.join(data, "translations/diet-names.toml"))

    @doc """
      Load the allergen names and translations.
    """
    @spec allergens(String.t) :: allergen_tree
    def allergens(data \\ @path), do: load(Path.join(data, "translations/allergen-names.toml"))

    @doc """
      Load the ingredient data.
    """
    @spec ingredients(String.t, String.t) :: ingredient_tree
    def ingredients(group \\ "", data \\ @path), do: load_tree(Path.join([data, "ingredients", group]))

    @doc """
      Reduce the ingredient data.
    """
    @spec reduce_ingredients(any, (ingredient_info, [{ String.t, ingredient_info }], any -> any), String.t) :: any
    def reduce_ingredients(acc, fun, group \\ "", data \\ @path), do: reduce_tree(Path.join([data, "ingredients", group]), acc, fun)

    @doc """
      Load the cuisine data.
    """
    @spec cuisines(String.t, String.t) :: cuisine_tree
    def cuisines(group \\ "", data \\ @path), do: load_tree(Path.join([data, "cuisines", group]))

    @doc """
      Reduce the cuisine data.
    """
    @spec reduce_cuisines(any, (cuisine_info, [{ String.t, cuisine_info }], any -> any), String.t) :: any
    def reduce_cuisines(acc, fun, group \\ "", data \\ @path), do: reduce_tree(Path.join([data, "cuisines", group]), acc, fun)

    defp load_tree(path) do
        Path.wildcard(Path.join(path, "**/*.toml"))
        |> Enum.reduce(%{}, fn file, acc ->
            [_|paths] = Enum.reverse(Path.split(Path.relative_to(file, path)))
            contents = Enum.reduce([Path.basename(file, ".toml")|paths], %{ __info__: load(file) }, fn name, contents ->
                %{ name => contents }
            end)

            Map.merge(acc, contents, &merge_nested_contents/3)
        end)
    end

    defp merge_nested_contents(_key, a, b), do: Map.merge(a, b, &merge_nested_contents/3)

    defp reduce_tree(path, acc, fun) do
        Path.wildcard(Path.join(path, "**/*.toml"))
        |> Enum.reduce({ [], acc }, fn file, { parent, acc } ->
            [name|paths] = Enum.reverse(Path.split(Path.relative_to(file, path)))

            parent = remove_stale_nodes(parent, paths)
            data = load(file)
            acc = fun.(data, parent, acc)

            { [{ Path.basename(name, ".toml"), data }|parent], acc }
        end)
        |> elem(1)
    end

    defp remove_stale_nodes([dep = { name, _ }], [name]), do: [dep]
    defp remove_stale_nodes([dep = { name, _ }|deps], [name|new_deps]), do: [dep|remove_stale_nodes(deps, new_deps)]
    defp remove_stale_nodes([_|deps], new_deps), do: remove_stale_nodes(deps, new_deps)
    defp remove_stale_nodes([], _), do: []
end
