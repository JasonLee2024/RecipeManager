BeforeAll {
    $ModuleRoot = Split-Path $PSScriptRoot -Parent
    Import-Module (Join-Path $ModuleRoot 'RecipeManager.psd1') -Force
}

Describe 'RecipeManager behavior checks' {
    It 'loads recipe data through public API' {
        $data = Get-Recipe
        $data | Should -Not -BeNullOrEmpty
        @($data).Count | Should -BeGreaterThan 0
    }

    It 'supports fuzzy name matching by default' {
        $result = Get-Recipe -Name '番茄'
        @($result).Count | Should -BeGreaterThan 0
        ($result | Select-Object -First 1).Name | Should -Match '番茄'
    }

    It 'supports regex name matching when -Regex is set' {
        $result = Get-Recipe -Name '^番茄炒蛋$' -Regex
        @($result).Count | Should -Be 1
        ($result | Select-Object -First 1).Name | Should -Be '番茄炒蛋'
    }

    It 'rejects category outside Settings enum in Set-Recipe' {
        {
            Set-Recipe -Name '番茄炒蛋' -Category '西式' -WhatIf -ErrorAction Stop
        } | Should -Throw
    }

    It 'accepts remove by ID parameter set without Name' {
        {
            Remove-Recipe -ID '00000000-0000-0000-0000-000000000000' -WhatIf -ErrorAction Stop
        } | Should -Not -Throw
    }
}
