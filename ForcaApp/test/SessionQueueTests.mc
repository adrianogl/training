import Toybox.Lang;
import Toybox.Test;

(:test)
module SessionQueueTests {
    function plan() {
        return [
            block("b1", 4, ["b1e1"]),
            block("b2", 4, ["b2e1"]),
            block("b3", 3, ["b3e1"]),
            block("b4", 2, ["b4e1", "b4e2"])
        ];
    }

    function block(id, rounds, exerciseIds) {
        var exercises = [];
        for (var i = 0; i < exerciseIds.size(); i++) {
            exercises.add({ PlanKeys.ID => exerciseIds[i] });
        }
        return { PlanKeys.ID => id, PlanKeys.ROUNDS => rounds, PlanKeys.EXERCISES => exercises };
    }

    function sameIds(actual, expected) {
        if (actual.size() != expected.size()) {
            return false;
        }
        for (var i = 0; i < expected.size(); i++) {
            if (!actual[i].equals(expected[i])) {
                return false;
            }
        }
        return true;
    }

    function blockIds(blocks) {
        var ids = [];
        for (var i = 0; i < blocks.size(); i++) {
            ids.add(blocks[i][PlanKeys.ID]);
        }
        return ids;
    }

    (:test)
    function skipWithTwoOfFourGoesToTheEnd(logger as Logger) as Boolean {
        var queue = new SessionQueue(plan());
        queue.setDone("b1e1");
        queue.setDone("b1e1");
        queue.skip("b1e1");
        Test.assert(sameIds(queue.order(), ["b2", "b3", "b4", "b1"]));
        Test.assertEqual(queue.current()[PlanKeys.ID], "b2");
        Test.assert(sameIds(blockIds(queue.pending()), ["b1"]));
        queue.doNow("b1e1");
        Test.assertEqual(queue.current()[PlanKeys.ID], "b1");
        Test.assertEqual(queue.doneCount("b1e1"), 2);
        return true;
    }

    (:test)
    function doNowSendsTheCurrentToTheEnd(logger as Logger) as Boolean {
        var queue = new SessionQueue(plan());
        queue.skip("b1e1");
        queue.setDone("b2e1");
        queue.doNow("b1e1");
        Test.assert(sameIds(queue.order(), ["b1", "b3", "b4", "b2"]));
        Test.assert(sameIds(blockIds(queue.pending()), ["b2"]));
        return true;
    }

    (:test)
    function doNowOnTheCurrentChangesNothing(logger as Logger) as Boolean {
        var queue = new SessionQueue(plan());
        queue.setDone("b1e1");
        queue.doNow("b1e1");
        Test.assert(sameIds(queue.order(), ["b1", "b2", "b3", "b4"]));
        Test.assertEqual(queue.pending().size(), 0);
        return true;
    }

    (:test)
    function doNowOnThePendingAtTheEndClearsIt(logger as Logger) as Boolean {
        var queue = new SessionQueue(plan());
        queue.skip("b1e1");
        for (var i = 0; i < 4; i++) { queue.setDone("b2e1"); }
        for (var i = 0; i < 3; i++) { queue.setDone("b3e1"); }
        for (var i = 0; i < 2; i++) { queue.setDone("b4e1"); queue.setDone("b4e2"); }
        Test.assertEqual(queue.current()[PlanKeys.ID], "b1");
        Test.assertEqual(queue.pending().size(), 1);
        queue.doNow("b1e1");
        Test.assertEqual(queue.pending().size(), 0);
        return true;
    }

    (:test)
    function leaveOutKeepsWhatWasDone(logger as Logger) as Boolean {
        var queue = new SessionQueue(plan());
        queue.setDone("b1e1");
        queue.skip("b1e1");
        queue.leaveOut("b1e1");
        Test.assert(sameIds(queue.leftOut(), ["b1"]));
        Test.assertEqual(queue.pending().size(), 0);
        Test.assertEqual(queue.doneCount("b1e1"), 1);
        Test.assertEqual(queue.current()[PlanKeys.ID], "b2");
        return true;
    }

    (:test)
    function biSetAlternatesWithinTheRound(logger as Logger) as Boolean {
        var queue = new SessionQueue(plan());
        queue.doNow("b4e1");
        Test.assertEqual(queue.nextExercise()[PlanKeys.ID], "b4e1");
        queue.setDone("b4e1");
        Test.assertEqual(queue.nextExercise()[PlanKeys.ID], "b4e2");
        queue.setDone("b4e2");
        Test.assertEqual(queue.nextExercise()[PlanKeys.ID], "b4e1");
        return true;
    }

    (:test)
    function unknownExerciseIsIgnored(logger as Logger) as Boolean {
        var queue = new SessionQueue(plan());
        queue.setDone("x");
        queue.skip("x");
        Test.assertEqual(queue.doneCount("x"), 0);
        Test.assert(sameIds(queue.order(), ["b1", "b2", "b3", "b4"]));
        return true;
    }
}
