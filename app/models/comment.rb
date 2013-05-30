class Comment < ActiveRecord::Base
  include IdentityCache

  belongs_to :user
  belongs_to :comment_thread, touch: true
  has_many :notifications, as: :notifiable

  acts_as_tree dependent: :destroy

  validates :user_id, :comment_thread_id, :body, presence: true
  validates :parent_id, inclusion: { in: -> (c) { c.comment_thread.comments.pluck(:id) } }, allow_blank: true

  scope :published, -> { where(published: true) }

  after_create :notify
  def notify
    title = comment_thread.threadable.title.blank? ? I18n.t("untitled") : comment_thread.threadable.title

    unless user == comment_thread.user
      # Notify owner
      notifications.create(
        send_email: true,
        user: comment_thread.user,
        subject: I18n.t("comments.notifications.subject", user: user.name, on: title),
        body: I18n.t("comments.notifications.body", user: user.name, on: title)
      )
    end
    
    # Notify replyee
    if child? && parent.user != comment_thread.user
      notifications.create(
        user: parent.user,
        subject: I18n.t("comments.notifications.reply.subject", user: user.name, on: title),
        body: I18n.t("comments.notifications.reply.body", user: user.name, on: title)
      )
    end
  end

  def can_be_seen_by?(current_user)
    if current_user == user || current_user == comment_thread.user
      true
    elsif child? && ancestors.map(&:user).include?(current_user)
      true
    elsif published?
      true
    else
      false
    end
  end

  def toggle_visibility
    self.published = !published
    saved = save

    if saved && published
      title = comment_thread.threadable.title.blank? ? I18n.t("untitled") : comment_thread.threadable.title

      notifications.create(
        user: user,
        subject: I18n.t("comments.notifications.published.subject", on: title)
      )
    end

    if child? && saved && published
      self.ancestors.find_each do |a|
        a.update_attribute(:published, published)
      end
    end

    saved
  end
end
