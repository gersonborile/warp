//! Personal fork: hides Warp's built-in AI (Warp Agent, cloud agents, AI credits) from the UI of
//! OSS builds. It only hides entry points; the underlying features stay compiled in.
//!
//! Features for third-party CLI coding agents (Claude Code, opencode, ...) are intentionally left
//! visible: the coding agent toolbar, Rich Input, agent notifications, and tab titles taken from
//! the latest prompt all apply to them too.

use warp_core::channel::{Channel, ChannelState};

use super::appearance_page::AppearancePageAction;
use super::code_editor_review_page::EditorAndCodeReviewPageAction;
use super::{SettingsAction, SettingsSection};

/// Whether Warp's built-in AI should be hidden from the UI.
pub fn hide_warp_ai() -> bool {
    ChannelState::channel() == Channel::Oss
}

/// Settings pages that only configure Warp's built-in AI or its cloud agents.
pub fn is_hidden_section(section: SettingsSection) -> bool {
    hide_warp_ai()
        && matches!(
            section,
            SettingsSection::WarpAgent
                | SettingsSection::AgentProfiles
                | SettingsSection::AgentMCPServers
                | SettingsSection::Knowledge
                | SettingsSection::BillingAndUsage
                | SettingsSection::CodeIndexing
                | SettingsSection::CloudEnvironments
                | SettingsSection::WarpCloudAgentAPIKeys
        )
}

/// Settings toggles (shown as "Enable/Disable ..." in the command palette) that only affect
/// Warp's built-in AI.
pub fn is_hidden_settings_action(action: &SettingsAction) -> bool {
    hide_warp_ai()
        && match action {
            SettingsAction::WarpAgent(_)
            | SettingsAction::AgentProfiles(_)
            | SettingsAction::Knowledge(_)
            | SettingsAction::CodeIndexing(_) => true,
            SettingsAction::SelectAndRefresh(section) => is_hidden_section(*section),
            SettingsAction::AppearancePageToggle(
                AppearancePageAction::ToggleMatchAIToTerminalFontFamily,
            ) => true,
            // Only fires on file edits made by Warp's own agent.
            SettingsAction::EditorAndCodeReview(
                EditorAndCodeReviewPageAction::ToggleAutoOpenCodeReviewPane,
            ) => true,
            _ => false,
        }
}
