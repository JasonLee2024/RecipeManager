function Start-RecipeManager {
    <#
    .SYNOPSIS
        启动持久化菜谱管理控制台循环。
    .DESCRIPTION
        基于 GuardianTree v3.0 标准。
        解决 Out-GridView 选后即关的问题，实现“选择->操作->刷新->再展示”的闭环体验。
    #>
    [CmdletBinding()]
    param()

    process {
        Write-Host "🚀 正在启动守望者熔炉管理中心..." -ForegroundColor Cyan

        $ExitManager = $false

        while (-not $ExitManager) {
            # 1. 呼叫 UI 获取用户选择
            # 注意：我们这里不直接管道传给 Remove，而是先接住选择
            $Selection = Invoke-RecipeUI

            if ($null -eq $Selection) {
                # 如果用户点击了“取消”或直接关掉窗口，则退出循环
                Write-Host "🚪 正在退出管理中心。" -ForegroundColor Yellow
                $ExitManager = $true
            }
            else {
                # 2. 执行业务操作
                # 这里会跳转到控制台询问 Y/N
                $Selection | Remove-Recipe

                Write-Host "`n按任意键继续下一次操作..." -ForegroundColor Gray
                $null = [Console]::ReadKey($true)
                
                # 循环会回到开头，重新执行 Invoke-RecipeUI，从而实现“自动刷新”
            }
        }
    }
}