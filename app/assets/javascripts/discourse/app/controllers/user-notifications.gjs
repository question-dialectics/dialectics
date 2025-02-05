import Controller from "@ember/controller";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DismissNotificationConfirmationModal from "discourse/components/modal/dismiss-notification-confirmation";
import RelativeDate from "discourse/components/relative-date";
import { ajax } from "discourse/lib/ajax";
import UserMenuNotificationItem from "discourse/lib/user-menu/notification-item";
import getURL from "discourse-common/lib/get-url";
import { iconHTML } from "discourse-common/lib/icon-library";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

export default class UserNotificationsController extends Controller {
  @service modal;
  @service appEvents;
  @service currentUser;
  @service site;
  @service siteSettings;

  queryParams = ["filter"];
  filter = "all";

  get listContainerClassNames() {
    return `user-notifications-list ${
      this.siteSettings.show_user_menu_avatars ? "show-avatars" : ""
    }`;
  }

  @discourseComputed("filter")
  isFiltered() {
    return this.filter && this.filter !== "all";
  }

  @discourseComputed("model.content.@each")
  items() {
    return this.model.map((notification) => {
      const props = {
        appEvents: this.appEvents,
        currentUser: this.currentUser,
        siteSettings: this.siteSettings,
        site: this.site,
        notification,
        endComponent: <template>
          <RelativeDate @date={{notification.created_at}} />
        </template>,
      };
      return new UserMenuNotificationItem(props);
    });
  }

  @discourseComputed("model.content.@each.read")
  allNotificationsRead() {
    return !this.get("model.content").some(
      (notification) => !notification.get("read")
    );
  }

  @discourseComputed("isFiltered", "model.content.length")
  doesNotHaveNotifications(isFiltered, contentLength) {
    return !isFiltered && contentLength === 0;
  }

  @discourseComputed("isFiltered", "model.content.length")
  nothingFound(isFiltered, contentLength) {
    return isFiltered && contentLength === 0;
  }

  @discourseComputed()
  emptyStateBody() {
    return htmlSafe(
      I18n.t("user.no_notifications_page_body", {
        preferencesUrl: getURL("/my/preferences/notifications"),
        icon: iconHTML("bell"),
      })
    );
  }

  async markRead() {
    await ajax("/notifications/mark-read", { type: "PUT" });
    this.model.forEach((notification) => notification.set("read", true));
  }

  @action
  async resetNew() {
    if (this.currentUser.unread_high_priority_notifications > 0) {
      this.modal.show(DismissNotificationConfirmationModal, {
        model: {
          confirmationMessage: I18n.t(
            "notifications.dismiss_confirmation.body.default",
            {
              count: this.currentUser.unread_high_priority_notifications,
            }
          ),
          dismissNotifications: () => this.markRead(),
        },
      });
    } else {
      this.markRead();
    }
  }

  @action
  loadMore() {
    this.model.loadMore();
  }
}
