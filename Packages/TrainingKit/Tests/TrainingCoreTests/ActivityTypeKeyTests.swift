import Testing
@testable import TrainingCore

@Test(arguments: ["running", "trail_running", "treadmill_running", "track_running", "virtual_run", "ultra_run", "obstacle_run"])
func recognizesRunTypeKeys(_ typeKey: String) {
    #expect(ActivityTypeKey.isRun(typeKey))
}

@Test(arguments: ["", "cycling", "strength_training", "running_drills", "run", "runningx", "indoor_rowing"])
func rejectsNonRunTypeKeys(_ typeKey: String) {
    #expect(!ActivityTypeKey.isRun(typeKey))
}
