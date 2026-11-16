import Toybox.Lang;

//! Label below the value of the bottom panel (above it in the top panel), e.g. "STEP" as in the reference.
//! PROVISIONAL: English capitals, the user has not decided the texts or their language (designer report).
//! Only characters of the bitmap fonts Value/Panel (A-Z, digits, space). "" = no label (none, weather, date).
module SlotLabels {
    const LABELS = [
        "", "", "BODY BATT", "BPM", "ACT KCAL", "KCAL", "STEP", "RUN KM", "BIKE KM", "SWIM M", "CLIMB",
        "TRAINING", "VO2 MAX", ""
    ] as Array<String>;

    function forKind(kind as Number) as String {
        if (kind < 0 || kind >= LABELS.size()) {
            return "";
        }
        return LABELS[kind];
    }
}
