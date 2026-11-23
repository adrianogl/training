import Toybox.Lang;

class SessionQueue {
    private var _blocks;
    private var _order = [];
    private var _skipped = [];
    private var _leftOut = [];
    private var _done = {};

    function initialize(blocks) {
        _blocks = blocks;
        for (var i = 0; i < blocks.size(); i++) {
            _order.add(blocks[i][PlanKeys.ID]);
        }
    }

    function order() {
        return _order;
    }

    function leftOut() {
        return _leftOut;
    }

    function doneCount(exerciseId) {
        var count = _done[exerciseId];
        return count == null ? 0 : count;
    }

    function setDone(exerciseId) {
        if (blockOf(exerciseId) == null) {
            return;
        }
        _done[exerciseId] = doneCount(exerciseId) + 1;
    }

    function current() {
        for (var i = 0; i < _order.size(); i++) {
            var block = blockById(_order[i]);
            if (!isComplete(block) && _leftOut.indexOf(_order[i]) < 0) {
                return block;
            }
        }
        return null;
    }

    function nextExercise() {
        var block = current();
        if (block == null) {
            return null;
        }
        var exercises = block[PlanKeys.EXERCISES];
        var best = exercises[0];
        for (var i = 1; i < exercises.size(); i++) {
            if (doneCount(exercises[i][PlanKeys.ID]) < doneCount(best[PlanKeys.ID])) {
                best = exercises[i];
            }
        }
        return best;
    }

    function pending() {
        var blocks = [];
        for (var i = 0; i < _skipped.size(); i++) {
            var block = blockById(_skipped[i]);
            if (!isComplete(block)) {
                blocks.add(block);
            }
        }
        return blocks;
    }

    function skip(exerciseId) {
        var block = blockOf(exerciseId);
        if (block == null || isComplete(block)) {
            return;
        }
        moveToEnd(block[PlanKeys.ID]);
    }

    function doNow(exerciseId) {
        var target = blockOf(exerciseId);
        if (target == null || isComplete(target)) {
            return;
        }
        var targetId = target[PlanKeys.ID];
        var running = current();
        if (running != null && running[PlanKeys.ID].equals(targetId)) {
            return;
        }
        _skipped.remove(targetId);
        _leftOut.remove(targetId);
        _order.remove(targetId);
        var index = running == null ? -1 : _order.indexOf(running[PlanKeys.ID]);
        if (index < 0) {
            _order = [targetId].addAll(_order);
            return;
        }
        _order = _order.slice(0, index).add(targetId).addAll(_order.slice(index, null));
        moveToEnd(running[PlanKeys.ID]);
    }

    function leaveOut(exerciseId) {
        var block = blockOf(exerciseId);
        if (block == null) {
            return;
        }
        var blockId = block[PlanKeys.ID];
        _skipped.remove(blockId);
        if (_leftOut.indexOf(blockId) < 0) {
            _leftOut.add(blockId);
        }
    }

    function isComplete(block) {
        var exercises = block[PlanKeys.EXERCISES];
        for (var i = 0; i < exercises.size(); i++) {
            if (doneCount(exercises[i][PlanKeys.ID]) < block[PlanKeys.ROUNDS]) {
                return false;
            }
        }
        return true;
    }

    private function moveToEnd(blockId) {
        _order.remove(blockId);
        _order.add(blockId);
        _skipped.remove(blockId);
        _skipped.add(blockId);
    }

    private function blockById(blockId) {
        for (var i = 0; i < _blocks.size(); i++) {
            if (_blocks[i][PlanKeys.ID].equals(blockId)) {
                return _blocks[i];
            }
        }
        return null;
    }

    private function blockOf(exerciseId) {
        for (var i = 0; i < _blocks.size(); i++) {
            var exercises = _blocks[i][PlanKeys.EXERCISES];
            for (var j = 0; j < exercises.size(); j++) {
                if (exercises[j][PlanKeys.ID].equals(exerciseId)) {
                    return _blocks[i];
                }
            }
        }
        return null;
    }
}
