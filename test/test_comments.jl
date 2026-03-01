@testset "Comments" begin
    @testset "Generic interface (experiments)" begin
        exp_id = create_experiment(title="Comment test exp")

        c1 = create_comment(:experiments, exp_id, "First comment")
        @test c1 isa Int

        c2 = create_comment(:experiments, exp_id, "Second comment")

        comments = list_comments(:experiments, exp_id)
        @test length(comments) == 2

        comment = get_comment(:experiments, exp_id, c1)
        @test comment["comment"] == "First comment"
        @test comment["id"] == c1

        update_comment(:experiments, exp_id, c1, "Updated comment")
        comment = get_comment(:experiments, exp_id, c1)
        @test comment["comment"] == "Updated comment"

        delete_comment(:experiments, exp_id, c1)
        comments = list_comments(:experiments, exp_id)
        @test length(comments) == 1

        delete_experiment(exp_id)
    end

    @testset "Convenience wrappers" begin
        exp_id = create_experiment(title="Convenience comment exp")
        item_id = create_item(title="Convenience comment item")

        ec = comment_experiment(exp_id, "Exp comment")
        @test ec isa Int
        exp_comments = list_experiment_comments(exp_id)
        @test length(exp_comments) == 1
        @test exp_comments[1]["comment"] == "Exp comment"

        ic = comment_item(item_id, "Item comment")
        @test ic isa Int
        item_comments = list_item_comments(item_id)
        @test length(item_comments) == 1
        @test item_comments[1]["comment"] == "Item comment"

        delete_experiment(exp_id)
        delete_item(item_id)
    end
end
