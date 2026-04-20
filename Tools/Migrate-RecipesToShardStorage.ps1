#Requires -Version 7.0
<#
.SYNOPSIS
    将单体 Data/Recipes.json 一次性迁移为 Data/Recipes/{Category}/*.json 分片存储（薄封装）。
.DESCRIPTION
    导入模块后调用公共命令 Migrate-RecipeStorage，避免在模块外调用私有 Invoke-DataProvider 时的参数展开问题。
.PARAMETER ModuleRoot
    模块根目录（含 RecipeManager.psd1）。默认为本脚本上级目录。
.PARAMETER Force
    在已存在分片文件时仍执行迁移。
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$ModuleRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [switch]$Force
)

$psd1 = Join-Path $ModuleRoot 'RecipeManager.psd1'
if (-not (Test-Path -LiteralPath $psd1)) {
    throw "未找到模块清单: $psd1"
}

Import-Module -Name $psd1 -Force
if ($Force) {
    Migrate-RecipeStorage -Force
}
else {
    Migrate-RecipeStorage
}
