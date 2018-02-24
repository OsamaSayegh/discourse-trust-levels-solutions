# name: discourse-trust-levels-solutions
# about: A plugin to make trust levels promotions require certain number of solutions
# version: 0.1
# authors: Osama Sayegh
# url: https://github.com/OsamaSayegh/discourse-trust-levels-solutions


after_initialize do
  require_dependency 'user_summary'
  require_dependency 'promotion'
  require 'trust_level3_requirements'

  module TrustLevelSolution
    def self.meet_criteria?(user, trust_level)
      return false unless user
      count = UserSummary.new(user, Guardian.new(user)).solved_count
      count >= SiteSetting.send("tl#{trust_level}_requires_solutions_count")
    end
  end

  class ::Promotion
    class << self
      alias_method :super_tl1_met?, :tl1_met?
      alias_method :super_tl2_met?, :tl2_met?

      def tl1_met?(user)
        TrustLevelSolution.meet_criteria?(user, 1) && super_tl1_met?(user)
      end

      def tl2_met?(user)
        TrustLevelSolution.meet_criteria?(user, 2) && super_tl2_met?(user)
      end
    end
  end

  class ::TrustLevel3Requirements
    alias_method :super_requirements_met?, :requirements_met?
    alias_method :super_requirements_lost?, :requirements_lost?

    def requirements_met?
      TrustLevelSolution.meet_criteria?(@user, 3) && super_requirements_met?
    end

    def requirements_lost?
      (!TrustLevelSolution.meet_criteria?(@user, 3)) || super_requirements_lost?
    end
  end

  [:accepted_solution, :unaccepted_solution].each do |event|
    DiscourseEvent.on(event) do |post|
      user = post.user
      Promotion.new(user).review if user.present?
    end
  end
end
