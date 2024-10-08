require "rails_helper"

RSpec.describe RatingHistoryEvent, type: :model do
  describe "events scope" do
    it "should return the RatingHistoryEvents associated with a player and event" do
      player = FactoryBot.create(:player)
      game = FactoryBot.create(:game)
      rating =
        FactoryBot.create(:rating, game: game, player: player, value: 1002)
      rating_history_events = [
        FactoryBot.create(:rating_history_event, rating: rating, value: 1001),
        FactoryBot.create(:rating_history_event, rating: rating, value: 1000)
      ]

      RatingHistoryEvent.events(player, game).should == rating_history_events
    end
  end
end
