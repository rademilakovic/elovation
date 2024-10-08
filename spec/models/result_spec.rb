require "rails_helper"

RSpec.describe Result, type: :model do
  describe "associations" do
    it "updates its game when modified" do
      game = FactoryBot.create(:game)
      updated = game.updated_at
      sleep(1)
      FactoryBot.create(:result, game_id: game.id)

      expect(updated).to_not(eq(game.reload.updated_at))
    end
  end

  describe "as_json" do
    it "returns the json representation of the result" do
      created_at = Time.now

      winner = FactoryBot.build(:team, rank: 1)
      loser = FactoryBot.build(:team, rank: 2)
      result =
        FactoryBot.build(
          :result,
          teams: [winner, loser],
          created_at: created_at
        )

      result.as_json.should ==
        {
          winner: winner.players.first.name,
          loser: loser.players.first.name,
          created_at: created_at.utc.to_s
        }
    end
  end

  describe "for_game" do
    it "finds results for the given game" do
      player = FactoryBot.create(:player)
      game1 = FactoryBot.create(:game)
      game2 = FactoryBot.create(:game)
      result_for_game1 =
        FactoryBot.create(
          :result,
          game: game1,
          teams: [
            FactoryBot.create(:team, rank: 1, players: [player]),
            FactoryBot.create(:team, rank: 2)
          ]
        )
      result_for_game2 =
        FactoryBot.create(
          :result,
          game: game2,
          teams: [
            FactoryBot.create(:team, rank: 1, players: [player]),
            FactoryBot.create(:team, rank: 2)
          ]
        )
      player.results.for_game(game1).should == [result_for_game1]
      player.results.for_game(game2).should == [result_for_game2]
    end
  end

  describe "most_recent?" do
    it "returns true if the result is the most recent for both players" do
      player_1 = FactoryBot.create(:player)
      player_2 = FactoryBot.create(:player)
      game = FactoryBot.create(:game)

      result =
        FactoryBot.create(
          :result,
          game: game,
          teams: [
            FactoryBot.create(:team, rank: 1, players: [player_1]),
            FactoryBot.create(:team, rank: 2, players: [player_2])
          ]
        )

      result.should(be_most_recent)
    end

    it "returns false if the result is not the most recent for both players" do
      player_1 = FactoryBot.create(:player)
      player_2 = FactoryBot.create(:player)
      player_3 = FactoryBot.create(:player)
      game = FactoryBot.create(:game)

      old_result =
        FactoryBot.create(
          :result,
          game: game,
          teams: [
            FactoryBot.create(:team, rank: 1, players: [player_1]),
            FactoryBot.create(:team, rank: 2, players: [player_2])
          ]
        )
      FactoryBot.create(
        :result,
        game: game,
        teams: [
          FactoryBot.create(:team, rank: 1, players: [player_1]),
          FactoryBot.create(:team, rank: 2, players: [player_3])
        ]
      )

      old_result.should_not(be_most_recent)
    end
  end

  describe "players" do
    it "has the winners and losers" do
      result = FactoryBot.create(:result)
      result.players.should(include(result.winners.first))
      result.players.should(include(result.losers.first))
    end
  end

  describe "winners" do
    it "has all the players in all the first place teams" do
      player1 = FactoryBot.create(:player)
      player2 = FactoryBot.create(:player)
      player3 = FactoryBot.create(:player)
      player4 = FactoryBot.create(:player)
      player5 = FactoryBot.create(:player)
      player6 = FactoryBot.create(:player)
      player7 = FactoryBot.create(:player)
      player7 = FactoryBot.create(:player)

      result = Result.new(game: FactoryBot.create(:game))

      result.teams.build(rank: 1, players: [player1, player2])
      result.teams.build(rank: 1, players: [player3, player4])
      result.teams.build(rank: 2, players: [player5, player6])
      result.teams.build(rank: 3, players: [player7, player7])

      result.winners.should == [player1, player2, player3, player4]
    end
  end

  describe "losers" do
    it "has all the players not in the first place teams" do
      player1 = FactoryBot.create(:player)
      player2 = FactoryBot.create(:player)
      player3 = FactoryBot.create(:player)
      player4 = FactoryBot.create(:player)
      player5 = FactoryBot.create(:player)
      player6 = FactoryBot.create(:player)
      player7 = FactoryBot.create(:player)
      player8 = FactoryBot.create(:player)

      result = Result.new(game: FactoryBot.create(:game))

      result.teams.build(rank: 1, players: [player1, player2])
      result.teams.build(rank: 1, players: [player3, player4])
      result.teams.build(rank: 2, players: [player5, player6])
      result.teams.build(rank: 3, players: [player7, player8])

      result.losers.should == [player5, player6, player7, player8]
    end
  end

  describe "validations" do
    context("team validations") do
      it "requires a winner" do
        player1 = FactoryBot.build(:player)
        player2 = FactoryBot.build(:player)
        result = Result.new(game: FactoryBot.create(:game))
        result.teams.build(rank: 2, players: [player1])
        result.teams.build(rank: 3, players: [player2])

        result.should_not(be_valid)
        result.errors[:teams].should(include("must have a winner"))
      end

      it "doesn't allow the same player twice" do
        player = FactoryBot.build(:player, name: nil)

        result = Result.new(game: FactoryBot.create(:game))
        result.teams.build(rank: 1, players: [player])
        result.teams.build(rank: 2, players: [player])

        result.should_not(be_valid)
        result.errors[:teams].should(include("must have unique players"))
      end

      it "does not complain about similarity when both winner and loser are nil" do
        result = Result.new(game: FactoryBot.create(:game))

        result.should_not(be_valid)
        result.errors[:base].should_not ==
          ["Winner and loser can't be the same player"]
      end

      it "cannot have less teams than allowed by the game" do
        player1 = FactoryBot.create(:player)
        player2 = FactoryBot.create(:player)
        player3 = FactoryBot.create(:player)

        game =
          FactoryBot.create(
            :game,
            min_number_of_teams: 4,
            max_number_of_teams: 5
          )

        result = Result.new(game: game)
        result.teams.build(rank: 1, players: [player1])
        result.teams.build(rank: 2, players: [player2])
        result.teams.build(rank: 2, players: [player3])

        result.should_not(be_valid)
        result.errors[:teams].should == ["must have at least 4 teams"]
      end

      it "cannot have more teams than allowed by the game" do
        player1 = FactoryBot.create(:player)
        player2 = FactoryBot.create(:player)
        player3 = FactoryBot.create(:player)
        player4 = FactoryBot.create(:player)
        player5 = FactoryBot.create(:player)

        game = FactoryBot.create(:game, max_number_of_teams: 4)

        result = Result.new(game: game)
        result.teams.build(rank: 1, players: [player1])
        result.teams.build(rank: 2, players: [player2])
        result.teams.build(rank: 2, players: [player3])
        result.teams.build(rank: 3, players: [player4])
        result.teams.build(rank: 2, players: [player5])

        result.should_not(be_valid)
        result.errors[:teams].should == ["must have at most 4 teams"]
      end

      it "can have any number of teams if not specified by the game" do
        player1 = FactoryBot.create(:player)
        player2 = FactoryBot.create(:player)
        player3 = FactoryBot.create(:player)
        player4 = FactoryBot.create(:player)
        player5 = FactoryBot.create(:player)
        player6 = FactoryBot.create(:player)

        game = FactoryBot.create(:game, max_number_of_teams: nil)

        result = Result.new(game: game)
        result.teams.build(rank: 1, players: [player1])
        result.teams.build(rank: 2, players: [player2])
        result.teams.build(rank: 2, players: [player3])
        result.teams.build(rank: 3, players: [player4])
        result.teams.build(rank: 2, players: [player5])
        result.teams.build(rank: 4, players: [player6])

        result.should(be_valid)
      end

      it "cannot have ties if not allowed by the game" do
        player1 = FactoryBot.create(:player)
        player2 = FactoryBot.create(:player)

        game = FactoryBot.create(:game, allow_ties: false)

        result = Result.new(game: game)
        result.teams.build(rank: 1, players: [player1])
        result.teams.build(rank: 1, players: [player2])

        result.should_not(be_valid)
        result.errors[:teams].should == ["game does not allow ties"]
      end

      describe "teams" do
        it "cannot have less players than allowed by the game" do
          player1 = FactoryBot.create(:player)
          player2 = FactoryBot.create(:player)
          player3 = FactoryBot.create(:player)

          game =
            FactoryBot.create(
              :game,
              min_number_of_players_per_team: 2,
              max_number_of_players_per_team: 2
            )

          result = Result.new(game: game)
          result.teams.build(rank: 1, players: [player1])
          result.teams.build(rank: 2, players: [player2, player3])

          result.should_not(be_valid)
          result.errors[:teams].should ==
            ["must have at least 2 players per team"]
        end

        it "cannot have more players than allowed by the game" do
          player1 = FactoryBot.create(:player)
          player2 = FactoryBot.create(:player)
          player3 = FactoryBot.create(:player)
          player4 = FactoryBot.create(:player)
          player5 = FactoryBot.create(:player)
          player6 = FactoryBot.create(:player)

          game =
            FactoryBot.create(
              :game,
              min_number_of_players_per_team: 2,
              max_number_of_players_per_team: 3
            )

          result = Result.new(game: game)
          result.teams.build(rank: 1, players: [player1, player2])
          result.teams.build(
            rank: 2,
            players: [player3, player4, player5, player6]
          )

          result.should_not(be_valid)
          result.errors[:teams].should ==
            ["must have at most 3 players per team"]
        end

        it "can have any number of players if not specified by the game" do
          player1 = FactoryBot.create(:player)
          player2 = FactoryBot.create(:player)
          player3 = FactoryBot.create(:player)
          player4 = FactoryBot.create(:player)
          player5 = FactoryBot.create(:player)
          player6 = FactoryBot.create(:player)

          game = FactoryBot.create(:game, max_number_of_players_per_team: nil)

          result = Result.new(game: game)
          result.teams.build(rank: 1, players: [player1])
          result.teams.build(
            rank: 2,
            players: [player2, player3, player4, player5, player6]
          )

          result.should(be_valid)
        end
      end
    end
  end
end
