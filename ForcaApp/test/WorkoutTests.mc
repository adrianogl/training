import Toybox.Lang;
import Toybox.Test;

(:test)
class FakeRecorder {
    var running = false;
    var saved = false;

    function start() { running = true; }
    function pause() { running = false; }
    function save() { saved = true; running = false; }
    function discard() { running = false; }
    function elapsedMs() { return 0; }
}

(:test)
class FakeServices {
    var recorder = new FakeRecorder();
    var clock = 0;
    var vibes = [];

    function now() { return clock; }
    function epoch() { return 1700000000 + clock / 1000; }
    function vibrate(kind) { vibes.add(kind); }
    function persists() { return false; }
}

(:test)
module WorkoutTests {
    function started(services) {
        var workout = new Workout(SamplePlan.superiores(), services);
        workout.start();
        return workout;
    }

    function tiny() {
        return {
            PlanKeys.TITLE => "Teste",
            PlanKeys.BLOCKS => [
                SamplePlan.block("b1", 1, 0, [SamplePlan.exercise("b1e1", "Remada", 10, null, 30.0, null)]),
                SamplePlan.block("b2", 1, 0, [SamplePlan.exercise("b2e1", "Supino", 10, null, 20.0, null)])
            ]
        };
    }

    (:test)
    function lapConcludesTheSetAndStartsTheRest(logger as Logger) as Boolean {
        var services = new FakeServices();
        var workout = started(services);
        Test.assertEqual(workout.phase, Phase.SET);
        Test.assertEqual(workout.current[PlanKeys.ID], "b1e1");
        workout.onLap();
        Test.assertEqual(workout.phase, Phase.REST);
        Test.assertEqual(workout.setsDone(), 1);
        Test.assertEqual(workout.restRemainingMs(), 90000);
        workout.onLap();
        Test.assertEqual(workout.phase, Phase.SET);
        return true;
    }

    (:test)
    function restVibratesAtTenSecondsAndAtZero(logger as Logger) as Boolean {
        var services = new FakeServices();
        var workout = started(services);
        workout.onLap();
        services.vibes = [];
        services.clock = 79000;
        workout.tick();
        Test.assertEqual(services.vibes.size(), 0);
        services.clock = 80000;
        workout.tick();
        Test.assertEqual(services.vibes[0], Vibe.WARN);
        services.clock = 90000;
        workout.tick();
        Test.assertEqual(services.vibes[1], Vibe.GO);
        services.clock = 112000;
        workout.tick();
        Test.assertEqual(services.vibes.size(), 2);
        Test.assertEqual(workout.phase, Phase.REST);
        Test.assertEqual(workout.restRemainingMs(), -22000);
        return true;
    }

    (:test)
    function adjustChangesTheSetAndTheNextPlan(logger as Logger) as Boolean {
        var services = new FakeServices();
        var workout = started(services);
        workout.onLap();
        workout.onStep(1);
        Test.assertEqual(workout.phase, Phase.ADJUST);
        Test.assertEqual(workout.adjust[:field], AdjustField.WEIGHT);
        workout.onStep(-1);
        Test.assert(workout.confirmAdjust());
        Test.assertEqual(workout.adjust[:field], AdjustField.REPS);
        workout.onStep(1);
        workout.onStep(1);
        workout.confirmAdjust();
        Test.assertEqual(workout.phase, Phase.REST);
        var set = workout.setsOf("b1e1")[0];
        Test.assertEqual(set[PlanKeys.WEIGHT], 32.5);
        Test.assertEqual(set[PlanKeys.REPS], 8);
        Test.assertEqual(workout.plannedWeight(workout.current), 32.5);
        return true;
    }

    (:test)
    function lapInTheAdjustCancels(logger as Logger) as Boolean {
        var services = new FakeServices();
        var workout = started(services);
        workout.onLap();
        workout.onStep(1);
        workout.onStep(-1);
        workout.onLap();
        Test.assertEqual(workout.phase, Phase.REST);
        Test.assertEqual(workout.setsOf("b1e1")[0][PlanKeys.WEIGHT], 30.0);
        return true;
    }

    (:test)
    function biSetGoesFromA1ToA2WithoutRest(logger as Logger) as Boolean {
        var services = new FakeServices();
        var workout = started(services);
        workout.doNow("b2e1");
        Test.assertEqual(workout.current[PlanKeys.ID], "b2e1");
        workout.onLap();
        Test.assertEqual(workout.phase, Phase.SET);
        Test.assertEqual(workout.current[PlanKeys.ID], "b2e2");
        workout.onLap();
        Test.assertEqual(workout.phase, Phase.REST);
        Test.assertEqual(workout.current[PlanKeys.ID], "b2e1");
        return true;
    }

    (:test)
    function timedSetStartsOnLapAndEndsAtZero(logger as Logger) as Boolean {
        var services = new FakeServices();
        var workout = started(services);
        workout.doNow("b5e1");
        Test.assertEqual(workout.phase, Phase.SET);
        workout.onLap();
        Test.assertEqual(workout.phase, Phase.TIMED);
        services.clock = 44000;
        workout.tick();
        Test.assertEqual(workout.phase, Phase.TIMED);
        services.clock = 45000;
        workout.tick();
        Test.assertEqual(workout.phase, Phase.REST);
        Test.assertEqual(workout.setsOf("b5e1")[0][PlanKeys.SECONDS], 45);
        return true;
    }

    (:test)
    function timedSetShowsTheCountdownEvenFromAnotherView(logger as Logger) as Boolean {
        var services = new FakeServices();
        var workout = started(services);
        workout.doNow("b5e1");
        workout.onStep(1);
        Test.assertEqual(workout.view, SetView.EXERCISE);
        workout.onLap();
        Test.assertEqual(workout.phase, Phase.TIMED);
        Test.assertEqual(workout.view, SetView.MAIN);
        return true;
    }

    (:test)
    function pauseFreezesTheRest(logger as Logger) as Boolean {
        var services = new FakeServices();
        var workout = started(services);
        workout.onLap();
        services.clock = 20000;
        workout.pause();
        Test.assert(!services.recorder.running);
        services.clock = 80000;
        Test.assertEqual(workout.restRemainingMs(), 70000);
        workout.onLap();
        Test.assertEqual(workout.phase, Phase.REST);
        workout.resume();
        Test.assert(services.recorder.running);
        Test.assertEqual(workout.restRemainingMs(), 70000);
        return true;
    }

    (:test)
    function viewsCycleAndReturnToTheMainOne(logger as Logger) as Boolean {
        var services = new FakeServices();
        var workout = started(services);
        workout.onStep(1);
        Test.assertEqual(workout.view, SetView.EXERCISE);
        workout.onStep(1);
        Test.assertEqual(workout.view, SetView.WORKOUT);
        workout.onStep(-1);
        workout.onStep(-1);
        workout.onStep(-1);
        Test.assertEqual(workout.view, SetView.WORKOUT);
        services.clock = 8000;
        workout.tick();
        Test.assertEqual(workout.view, SetView.MAIN);
        return true;
    }

    (:test)
    function skippedExerciseAsksAtTheEnd(logger as Logger) as Boolean {
        var services = new FakeServices();
        var workout = new Workout(tiny(), services);
        workout.start();
        workout.skip();
        Test.assertEqual(workout.current[PlanKeys.ID], "b2e1");
        workout.onLap();
        Test.assertEqual(workout.phase, Phase.EXERCISE_DONE);
        services.clock = 3000;
        workout.tick();
        Test.assertEqual(workout.phase, Phase.PENDING);
        Test.assertEqual(workout.current[PlanKeys.ID], "b1e1");
        workout.doNow("b1e1");
        Test.assertEqual(workout.phase, Phase.SET);
        workout.onLap();
        services.clock = 6000;
        workout.tick();
        Test.assertEqual(workout.phase, Phase.FINISHED);
        return true;
    }

    (:test)
    function leaveOutFinishesWithWhatWasDone(logger as Logger) as Boolean {
        var services = new FakeServices();
        var workout = new Workout(tiny(), services);
        workout.start();
        workout.skip();
        workout.onLap();
        services.clock = 3000;
        workout.tick();
        workout.leaveOut("b1e1");
        Test.assertEqual(workout.phase, Phase.FINISHED);
        Test.assertEqual(workout.setsDone(), 1);
        workout.pause();
        workout.save();
        Test.assert(services.recorder.saved);
        Test.assertEqual(workout.phase, Phase.SAVED);
        return true;
    }

    (:test)
    function everyActionBecomesAnOrderedEvent(logger as Logger) as Boolean {
        var services = new FakeServices();
        var workout = started(services);
        workout.onLap();
        workout.onStep(1);
        workout.onStep(-1);
        workout.confirmAdjust();
        workout.confirmAdjust();
        workout.skip();
        workout.doNow("b1e1");
        var events = workout.log.events;
        Test.assertEqual(events.size(), 4);
        Test.assertEqual(events[0][EventKeys.SEQUENCE], 1);
        Test.assertEqual(events[0][EventKeys.ID], "1700000000-1");
        var done = events[0][EventKeys.ACTION][EventKeys.SET_DONE];
        Test.assertEqual(done[EventKeys.EXERCISE_ID], "b1e1");
        Test.assertEqual(done[EventKeys.RESULT][PlanKeys.REPS], 10);
        Test.assertEqual(done[EventKeys.RESULT][PlanKeys.WEIGHT], 30.0);
        var adjusted = events[1][EventKeys.ACTION][EventKeys.ADJUST];
        Test.assertEqual(adjusted[EventKeys.SET_INDEX], 0);
        Test.assertEqual(adjusted[EventKeys.RESULT][PlanKeys.WEIGHT], 32.5);
        Test.assertEqual(events[2][EventKeys.ACTION][EventKeys.SKIP][EventKeys.EXERCISE_ID], "b1e1");
        Test.assertEqual(events[3][EventKeys.ACTION][EventKeys.DO_NOW][EventKeys.EXERCISE_ID], "b1e1");
        return true;
    }

    (:test)
    function planFromThePhoneReplacesOnlyBeforeTheStart(logger as Logger) as Boolean {
        var workout = new Workout(SamplePlan.superiores(), new FakeServices());
        Test.assert(workout.usePlan(tiny()));
        Test.assertEqual(workout.plan[PlanKeys.TITLE], "Teste");
        Test.assertEqual(workout.setsPlanned(), 2);
        workout.start();
        Test.assert(!workout.usePlan(SamplePlan.superiores()));
        Test.assertEqual(workout.plan[PlanKeys.TITLE], "Teste");
        return true;
    }

    (:test)
    function emptyWatchStartsWithThePlanFromThePhone(logger as Logger) as Boolean {
        var workout = new Workout(null, new FakeServices());
        Test.assertEqual(workout.phase, Phase.EMPTY);
        Test.assert(workout.usePlan(tiny()));
        Test.assertEqual(workout.phase, Phase.START);
        return true;
    }
}
