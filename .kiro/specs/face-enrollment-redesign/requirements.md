# Requirements Document

## Introduction

The Face Enrollment screen in the ELECOM mobile app currently uses a heavy black AppBar, a dark brand color scheme, and a minimal layout that feels disconnected from the rest of the app. This feature redesigns the Face Enrollment screen so that it is visually consistent with the Home screen (StudentDashboard): light background, soft rounded white cards, subtle shadows, blue (`0xFF0c1e70`) and yellow (`0xFFFEA501`) accent colors, a clean header, an oval face-frame placeholder, a bottom navigation bar, and the same rounded button style used throughout the dashboard.

All existing business logic (face capture, liveness check, upload, logout, contact-support sheet) is preserved unchanged. Only the visual layer is modified.

---

## Glossary

- **FaceEnrollmentScreen**: The Flutter `StatefulWidget` at `lib/features/elecom/face/face_enrollment_screen.dart` that orchestrates face capture and enrollment upload.
- **Home_Screen**: The `StudentDashboard` widget and its child `_homeTab`, which defines the reference design style.
- **Brand_Blue**: The deep navy color `Color(0xFF0c1e70)` used as the primary accent in the Home screen countdown card and buttons.
- **Brand_Yellow**: The amber color `Color(0xFFFEA501)` used as the secondary accent (profile avatar border, gradient endpoint).
- **Light_Background**: The scaffold background color `Color(0xFFF4F6FA)` (or equivalent light gray) used on the Home screen.
- **Rounded_Card**: A `Container` with `BorderRadius.circular(18)`, white fill, and a soft `BoxShadow` matching the Home screen card style.
- **Header**: The top area of the screen replacing the current black `AppBar`, styled to match `StudentDashboardAppBar` (light background, no elevation, title left-aligned, logout action right-aligned).
- **Face_Frame_Area**: A visual placeholder — an oval or rounded-rectangle outline — that communicates to the user that this screen is for face capture, displayed below the instruction card.
- **Instruction_Card**: The `Rounded_Card` that shows the ELECOM logo, the enrollment title, and the explanatory subtitle.
- **Status_Card**: The `Rounded_Card` that shows the current status message (idle, busy, error).
- **Enroll_Button**: The primary CTA button ("Start face enrollment" / "Retry upload") styled to match Home screen buttons.
- **Bottom_Nav_Bar**: The `BottomNavigationBar` identical in structure to the one in `StudentDashboard`, keeping the user oriented within the app.
- **Support_FAB**: The `FloatingActionButton` that opens the contact-support bottom sheet.

---

## Requirements

### Requirement 1: Light Background and Scaffold Theme

**User Story:** As a voter, I want the Face Enrollment screen to feel like part of the same app as the Home screen, so that I am not confused by a sudden visual change.

#### Acceptance Criteria

1. THE FaceEnrollmentScreen SHALL use `Color(0xFFF4F6FA)` as the scaffold background color.
2. WHEN the FaceEnrollmentScreen is rendered, THE AppBar (or equivalent header widget) SHALL have a background color equal to `Color(0xFFF4F6FA)` and an elevation of 0, so that no dark bar is visible at the top of the screen.
3. THE FaceEnrollmentScreen SHALL wrap its body content in a `SafeArea` widget so that content is not obscured by system UI (status bar, notch, home indicator) on any device.

---

### Requirement 2: Clean Header Replacing the Black AppBar

**User Story:** As a voter, I want a clean, light header on the Face Enrollment screen that matches the Home screen style, so that the transition between screens feels seamless.

#### Acceptance Criteria

1. THE Header SHALL display the title text "Face Enrollment" left-aligned, using `FontWeight.w900` and color `Color(0xFF1A1A2E)`.
2. THE Header SHALL display a logout icon (`Icons.logout`) as an action button right-aligned, with icon color `Color(0xFF1A1A2E)`.
3. WHEN the logout icon button is tapped, THE FaceEnrollmentScreen SHALL display a confirmation dialog; upon confirmation, it SHALL clear the user session and navigate to `LoginScreen`, removing all previous routes from the stack.
4. THE Header SHALL have elevation 0 and background color `Color(0xFFF4F6FA)`, matching the scaffold background so no shadow or color break is visible between the header and the body.
5. WHEN `widget.isMandatory` is true, THE Header SHALL display no back-navigation arrow, AND the system back gesture SHALL be blocked (via `PopScope` with `canPop: false`), so that the user cannot exit without completing enrollment or tapping logout.
6. IF `widget.isMandatory` is false, THEN THE Header SHALL display a back-navigation arrow on the left side; WHEN tapped, it SHALL pop the current screen from the navigation stack.

---

### Requirement 3: Instruction Card with ELECOM Logo, Title, and Subtitle

**User Story:** As a voter, I want a clearly structured instruction card that shows the ELECOM logo, a prominent title, and a short explanation, so that I immediately understand the purpose of this screen.

#### Acceptance Criteria

1. THE Instruction_Card SHALL have a white background, `BorderRadius.circular(18)`, and a `BoxShadow` with `blurRadius: 14`, `offset: Offset(0, 6)`, and `color: Color(0x14000000)`.
2. THE Instruction_Card SHALL display the ELECOM fingerprint logo at 40×40 logical pixels, vertically centered alongside the title text; IF the logo asset fails to load, a fallback icon (`Icons.fingerprint`, size 40, color Brand_Blue) SHALL be displayed in its place.
3. THE Instruction_Card SHALL display the title "Enroll your official voting face reference" in `FontWeight.w900`, `fontSize: 18`, color `Color(0xFF0c1e70)`.
4. THE Instruction_Card SHALL display the subtitle "Your enrolled face image is used only for voting identity verification and is not shown publicly." in `FontWeight.w600`, `fontSize: 13`, color `Color(0xFF4A4A6A)`.
5. THE Instruction_Card SHALL include a top border accent: a 3 dp solid line in `Color(0xFF0c1e70)` rendered as the top edge of the card's decoration border.

---

### Requirement 4: Face Frame Placeholder Area

**User Story:** As a voter, I want to see a visual face-frame area on the enrollment screen, so that I immediately understand that this screen involves capturing my face.

#### Acceptance Criteria

1. THE Face_Frame_Area SHALL be displayed below the Instruction_Card and above the Status_Card in the vertical layout.
2. THE Face_Frame_Area SHALL render an oval outline with a stroke width of 3 dp and stroke color `Color(0xFF0c1e70)`.
3. THE Face_Frame_Area oval SHALL have a fixed height of 220 logical pixels and a width of 180 logical pixels, centered horizontally within its parent.
4. WHEN no capture or upload is in progress, THE Face_Frame_Area SHALL display a face or camera icon centered inside the oval at size 64, color `Color(0xFF0c1e70)` at 35% opacity.
5. THE Face_Frame_Area SHALL be contained within a card with white background, `BorderRadius.circular(18)`, and the same `BoxShadow` as the Instruction_Card, so it is visually grouped with the other cards.
6. WHEN a capture or upload operation is in progress, THE Face_Frame_Area SHALL display a `CircularProgressIndicator` in `Color(0xFF0c1e70)` with `strokeWidth: 3` centered inside the oval, replacing the static icon.
7. WHEN a capture or upload operation completes (successfully or with failure), THE Face_Frame_Area SHALL revert to displaying the static icon, replacing the progress indicator.

---

### Requirement 5: Status Card

**User Story:** As a voter, I want to see a clear status message that tells me what is happening (idle, uploading, error), so that I am never left wondering about the state of my enrollment.

#### Acceptance Criteria

1. THE Status_Card SHALL use the Rounded_Card style with a left-side accent bar 4 dp wide; the accent bar color SHALL be `Color(0xFF0c1e70)` when the status is idle or uploading, and `Color(0xFFB91C1C)` when an upload failure has occurred.
2. WHEN a capture or upload is in progress AND no upload failure has occurred, THE Status_Card SHALL display a `CircularProgressIndicator` (constrained to 18×18 logical pixels, `strokeWidth: 2`) as the leading widget.
3. WHEN an upload failure has occurred, THE Status_Card SHALL display `Icons.error_outline` in `Color(0xFFB91C1C)` as the leading widget, regardless of whether a capture or upload is also in progress.
4. WHEN the screen is in the idle state (no operation in progress, no upload failure), THE Status_Card SHALL display `Icons.info_outline` in `Color(0xFF0c1e70)` as the leading widget.
5. THE Status_Card SHALL display the current status string in `FontWeight.w700`, `fontSize: 13`; the text color SHALL match the accent bar color for the current state.
6. THE status string SHALL be "Position your face inside the frame, then follow the on-camera steps." in the idle state, a progress description (e.g., "Uploading…") during an active operation, and an error description (e.g., "Upload failed. Please try again.") when an upload failure has occurred.

---

### Requirement 6: Enroll Button Styled to Match Home Screen Buttons

**User Story:** As a voter, I want the "Start face enrollment" button to look and feel like the action buttons on the Home screen, so that the interaction feels familiar and trustworthy.

#### Acceptance Criteria

1. THE Enroll_Button SHALL use `FilledButton.icon` with `backgroundColor: Color(0xFF0c1e70)` (Brand_Blue) and `foregroundColor: Colors.white`.
2. THE Enroll_Button SHALL have `minimumSize: Size.fromHeight(54)` and `BorderRadius.circular(16)`, matching the rounded style of Home screen action buttons.
3. THE Enroll_Button SHALL display `Icons.camera_alt_outlined` as the leading icon when no upload failure has occurred, and `Icons.refresh_rounded` when an upload failure has occurred.
4. THE Enroll_Button SHALL display the label "Start face enrollment" when no upload failure has occurred, and "Retry upload" when an upload failure has occurred, in `FontWeight.w800`.
5. WHEN a capture or upload is in progress, THE Enroll_Button SHALL be disabled (onPressed set to null) so that the user cannot trigger a second capture while one is in progress.
6. THE Enroll_Button SHALL be placed below the Status_Card with a vertical spacing of 16 logical pixels.

---

### Requirement 7: Bottom Navigation Bar

**User Story:** As a voter, I want to see the same bottom navigation bar on the Face Enrollment screen as on the Home screen, so that I feel I am still inside the ELECOM app and can orient myself.

#### Acceptance Criteria

1. THE FaceEnrollmentScreen SHALL include a `BottomNavigationBar` with five items: Home, Election, Results, Receipt, Me — using icons `Icons.home_outlined`, `Icons.how_to_vote_outlined`, `Icons.bar_chart_outlined`, `Icons.receipt_long_outlined`, `Icons.person_outline` respectively.
2. THE Bottom_Nav_Bar SHALL display with `selectedItemColor: Color(0xFF0c1e70)`, `unselectedItemColor: Colors.black54`, and `backgroundColor: Colors.white`.
3. THE Bottom_Nav_Bar SHALL highlight the "Home" item (index 0) as the selected item.
4. WHEN any Bottom_Nav_Bar item is tapped, THE FaceEnrollmentScreen SHALL navigate to `ElecomDashboard` using `Navigator.pushAndRemoveUntil`, clearing the enrollment screen from the stack, AND the `ElecomDashboard` SHALL open with the tapped tab index active.
5. THE Bottom_Nav_Bar navigation SHALL always navigate to `ElecomDashboard` regardless of whether `widget.isMandatory` is true or false.

---

### Requirement 8: Support FAB Styling Consistency

**User Story:** As a voter, I want the support floating action button to match the overall redesigned style, so that the screen looks cohesive.

#### Acceptance Criteria

1. THE Support_FAB SHALL use `backgroundColor: Color(0xFF0c1e70)` and `foregroundColor: Colors.white`, replacing the current black background.
2. THE Support_FAB SHALL retain `Icons.support_agent_rounded` as its icon and SHALL call `_showContactSupportSheet()` when tapped.
3. THE Support_FAB SHALL retain its `tooltip: 'Contact support'` label.

---

### Requirement 9: Preservation of Existing Business Logic

**User Story:** As a developer, I want all existing enrollment, liveness check, upload, logout, and support-contact logic to remain unchanged, so that the redesign does not introduce regressions.

#### Acceptance Criteria

1. WHEN the Enroll_Button is tapped, THE FaceEnrollmentScreen SHALL navigate to `LiveFaceCaptureScreen`; upon receiving a liveness result, it SHALL call `_api.saveFaceEnrollment()` with the captured data; upon success it SHALL display a success dialog; upon failure it SHALL display a failure dialog and set the upload-failed state.
2. WHEN the logout action is confirmed, THE FaceEnrollmentScreen SHALL clear the user session and navigate to `LoginScreen`, removing all previous routes from the stack.
3. WHEN the Support_FAB is tapped, THE FaceEnrollmentScreen SHALL display a bottom sheet offering Messenger and email support contact options, with the same behavior as the current implementation.
4. THE FaceEnrollmentScreen SHALL preserve the `widget.isMandatory` and `widget.navigateToDashboardOnSuccess` constructor parameters and their behavioral effects on navigation and back-gesture handling.
5. WHEN enrollment succeeds and `widget.navigateToDashboardOnSuccess` is true, THE FaceEnrollmentScreen SHALL navigate to `ElecomDashboard` using `Navigator.pushAndRemoveUntil`.

---

### Requirement 10: Mobile-Friendly, Balanced Layout

**User Story:** As a voter using a mobile device, I want the Face Enrollment screen to be well-proportioned and not feel empty or cramped, so that the experience is comfortable on any phone screen size.

#### Acceptance Criteria

1. THE FaceEnrollmentScreen body SHALL use a `SingleChildScrollView` so that the content is accessible on small screens without overflow.
2. THE FaceEnrollmentScreen SHALL apply consistent horizontal and vertical padding of 16 logical pixels around the scrollable content area.
3. THE FaceEnrollmentScreen SHALL constrain the content to a maximum width of 600 logical pixels, centered horizontally, so that the layout does not stretch excessively on wide screens or tablets.
4. WHEN the screen height is less than 600 logical pixels but greater than 300 logical pixels, THE FaceEnrollmentScreen SHALL remain fully scrollable without any content being clipped or inaccessible.
5. THE FaceEnrollmentScreen SHALL maintain a vertical spacing of 14 logical pixels between each major card section (Instruction_Card, Face_Frame_Area, Status_Card, Enroll_Button) for visual breathing room.
