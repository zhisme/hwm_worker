# frozen_string_literal: true

require 'config/urls'
require 'helpers/work_logger'

##
# Check mirror durability before hunt
#
module InventoryCheck
  extend self

  class MirrorLowDurability < StandardError; end

  INVENTORY_URL = "#{HEROESWM_URL}/inventory.php".freeze
  MIRROR_SLOT_SELECTOR = '#slot11 .art_durability_hidden'

  def call(session:, user:)
    check_mirror_durability(session, user)
  end

  private

  def check_mirror_durability(session, user)
    session.visit(INVENTORY_URL)
    durability_el = session.find(MIRROR_SLOT_SELECTOR, visible: :all)
    durability_text = durability_el.text(:all)

    current, max = durability_text.split('/').map(&:to_i)

    WorkLogger.current.info { "mirror durability user=#{user.login} #{current}/#{max}" }

    return if current > 1

    raise MirrorLowDurability,
      "Mirror durability is #{durability_text} for #{user.login}. Sell it now!"
  end
end
