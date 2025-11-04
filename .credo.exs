%{
  configs: [
    %{
      name: "default",
      checks: [
        {Credo.Check.Design.TagTODO, false},
        {Credo.Check.Refactor.RedundantWithClauseResult, false},
        {Credo.Check.Refactor.CyclomaticComplexity, false}
      ]
    }
  ]
}
