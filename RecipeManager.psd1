@{
    RootModule = 'RecipeManager.psm1'
    ModuleVersion = '1.2.2'
    GUID = 'd4f2cf7e-5e52-4b77-93a0-1884e63f14f2'
    PowerShellVersion = '7.0'
    Author = 'MasterGuardian Architect'
    Description = 'RecipeManager module for local recipe CRUD, validation and UI management.'
    FunctionsToExport = @(
        'Get-Recipe',
        'Migrate-RecipeStorage',
        'New-Recipe',
        'Remove-Recipe',
        'Set-Recipe',
        'Update-RecipeIngredientTags',
        'Start-RecipeManager',
        'Get-CookingWorkflow',
        'Get-HerbalMaterial',
        'Test-HerbalMaterial',
        'Get-BeverageTaxonomy',
        'Sync-RecipeDocs',
        'Invoke-RecipeUI'
    )
}