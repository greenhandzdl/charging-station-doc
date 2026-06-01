# 遍历 code 下的每一个子目录（假设都是 git 仓库 / submodule）
for dir in code/*/
    if test -d "$dir/.git"
        echo "🔄 正在处理子模块: $dir"
        pushd $dir > /dev/null

        # 获取当前分支名（如果处于 detached HEAD，分支名为 HEAD）
        set branch (git rev-parse --abbrev-ref HEAD)

        if test "$branch" = "HEAD"
            echo "⚠️  跳过 $dir ：当前处于 detached HEAD 状态，无法直接 push"
        else
            echo "📤 推送分支 $branch 到 origin ..."
            git push origin $branch
            if test $status -eq 0
                echo "✅ $dir 推送成功"
            else
                echo "❌ $dir 推送失败，请手动检查"
            end
        end

        popd > /dev/null
    else
        echo "⏭️  跳过 $dir：不是 Git 仓库"
    end
end
