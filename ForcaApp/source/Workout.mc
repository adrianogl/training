import Toybox.Lang;

class Workout {
    var plan;
    var queue;
    var phase = Phase.START;
    var view = SetView.MAIN;
    var current = null;
    var results = {};
    var adjust = null;
    var lastDone = null;
    var restTotalMs = 0;
    var timedSeconds = 0;
    var paused = false;
    var savedSeconds = 0;
    var savedHeartRate = null;
    var log;

    private var _svc;
    private var _setStartMs = 0;
    private var _setStartEpoch = 0;
    private var _restEndMs = 0;
    private var _timedEndMs = 0;
    private var _doneUntilMs = 0;
    private var _viewChangedMs = 0;
    private var _pausedAtMs = 0;
    private var _warned = false;
    private var _restOver = false;
    private var _finishedBlock = null;
    private var _overrides = {};

    function initialize(aPlan, services) {
        plan = aPlan;
        _svc = services;
        log = new EventLog(services.epoch(), services.persists());
        if (plan == null) {
            phase = Phase.EMPTY;
            queue = new SessionQueue([]);
            return;
        }
        queue = new SessionQueue(plan[PlanKeys.BLOCKS]);
    }

    function usePlan(aPlan) {
        if (aPlan == null || (phase != Phase.START && phase != Phase.EMPTY)) {
            return false;
        }
        plan = aPlan;
        phase = Phase.START;
        queue = new SessionQueue(plan[PlanKeys.BLOCKS]);
        return true;
    }

    function start() {
        if (phase != Phase.START) {
            return;
        }
        WorkoutStore.clearSession();
        _svc.recorder.start(plan[PlanKeys.TITLE]);
        _svc.vibrate(Vibe.GO);
        log.started(plan[PlanKeys.TITLE], plan[PlanKeys.VERSION], plan);
        beginSet();
    }

    function onLap() {
        if (paused) {
            return;
        }
        if (phase == Phase.SET) {
            if (isTimed(current)) {
                startTimed();
            } else {
                completeSet(null);
            }
        } else if (phase == Phase.TIMED) {
            completeSet(elapsedTimedSeconds());
        } else if (phase == Phase.REST) {
            beginSet();
        } else if (phase == Phase.ADJUST) {
            adjust = null;
            phase = Phase.REST;
        } else if (phase == Phase.EXERCISE_DONE) {
            afterExerciseDone();
        }
    }

    function onStep(direction) {
        if (paused) {
            return;
        }
        if (phase == Phase.SET) {
            view = (view + direction + SetView.COUNT) % SetView.COUNT;
            _viewChangedMs = _svc.now();
        } else if (phase == Phase.REST && lastDone != null) {
            openAdjust();
        } else if (phase == Phase.ADJUST) {
            stepAdjust(-direction);
        }
    }

    function confirmAdjust() {
        if (phase != Phase.ADJUST) {
            return false;
        }
        var fields = adjustFields();
        var position = fields.indexOf(adjust[:field]);
        if (position + 1 < fields.size()) {
            adjust[:field] = fields[position + 1];
            return true;
        }
        var set = results[lastDone[:exercise]][lastDone[:index]];
        if (set[PlanKeys.WEIGHT] != adjust[AdjustField.WEIGHT]) {
            _overrides.remove(lastDone[:exercise]);
        }
        set[PlanKeys.REPS] = adjust[AdjustField.REPS];
        set[PlanKeys.WEIGHT] = adjust[AdjustField.WEIGHT];
        set[PlanKeys.SECONDS] = adjust[AdjustField.SECONDS];
        WorkoutStore.saveResults(results);
        log.adjust(lastDone[:exercise], lastDone[:index], set);
        adjust = null;
        phase = Phase.REST;
        return true;
    }

    function pause() {
        if (paused || !isRunning()) {
            return;
        }
        paused = true;
        _pausedAtMs = _svc.now();
        _svc.recorder.pause();
    }

    function resume() {
        if (!paused) {
            return;
        }
        var pausedFor = _svc.now() - _pausedAtMs;
        _restEndMs += pausedFor;
        _timedEndMs += pausedFor;
        _doneUntilMs += pausedFor;
        _setStartMs += pausedFor;
        paused = false;
        _svc.recorder.start(plan[PlanKeys.TITLE]);
    }

    function elapsedSeconds() {
        return _svc.recorder.elapsedMs() / 1000;
    }

    function save() {
        savedSeconds = elapsedSeconds();
        savedHeartRate = Services.averageHeartRate();
        _svc.recorder.save();
        WorkoutStore.saveResults(results);
        paused = false;
        phase = Phase.SAVED;
        _svc.vibrate(Vibe.DONE);
        log.finished(true, savedSeconds, savedHeartRate);
    }

    function discard() {
        _svc.recorder.discard();
        WorkoutStore.clearSession();
        paused = false;
        phase = Phase.DISCARDED;
        log.finished(false, elapsedSeconds(), null);
    }

    function skip() {
        if (current == null || !(phase == Phase.SET || phase == Phase.REST)) {
            return;
        }
        queue.skip(current[PlanKeys.ID]);
        log.skip(current[PlanKeys.ID]);
        beginSet();
    }

    function doNow(exerciseId) {
        queue.doNow(exerciseId);
        log.doNow(exerciseId);
        beginSet();
    }

    function setWeight(payload) {
        if (!(payload instanceof Dictionary) || plan == null || phase == Phase.SAVED || phase == Phase.DISCARDED) {
            return false;
        }
        var exerciseId = payload[EventKeys.EXERCISE_ID];
        if (exerciseId == null || findExercise(exerciseId) == null) {
            return false;
        }
        var bodyweight = payload[EventKeys.BODYWEIGHT] == true;
        var weight = bodyweight ? null : payload[EventKeys.WEIGHT];
        var nextOnly = payload[EventKeys.NEXT_ONLY] == true;
        _overrides[exerciseId] = { EventKeys.WEIGHT => weight, EventKeys.BODYWEIGHT => bodyweight, EventKeys.NEXT_ONLY => nextOnly };
        log.setWeight(exerciseId, weight, bodyweight, nextOnly);
        return true;
    }

    function command(kind, exerciseId) {
        if (EventKeys.SET_WEIGHT.equals(kind)) {
            return setWeight(exerciseId);
        }
        if (paused || exerciseId == null) {
            return false;
        }
        if (EventKeys.SKIP.equals(kind)) {
            if (current == null || !exerciseId.equals(current[PlanKeys.ID])) {
                return false;
            }
            skip();
            return true;
        }
        if (EventKeys.DO_NOW.equals(kind) && (phase == Phase.SET || phase == Phase.REST || phase == Phase.PENDING)) {
            doNow(exerciseId);
            return true;
        }
        return false;
    }

    function leaveOut(exerciseId) {
        queue.leaveOut(exerciseId);
        log.leaveOut(exerciseId);
        beginSet();
    }

    function tick() {
        if (paused) {
            return;
        }
        var now = _svc.now();
        if (phase == Phase.REST || phase == Phase.ADJUST) {
            var remaining = _restEndMs - now;
            if (!_warned && remaining <= Timing.REST_WARN_S * 1000) {
                _warned = true;
                _svc.vibrate(Vibe.WARN);
            }
            if (!_restOver && remaining <= 0) {
                _restOver = true;
                _svc.vibrate(Vibe.GO);
            }
            if (_restOver && phase == Phase.REST) {
                beginSet();
            }
        } else if (phase == Phase.TIMED && now >= _timedEndMs) {
            completeSet(timedSeconds);
        } else if (phase == Phase.EXERCISE_DONE && now >= _doneUntilMs) {
            afterExerciseDone();
        } else if (phase == Phase.SET && view != SetView.MAIN && now - _viewChangedMs >= Timing.VIEW_RETURN_MS) {
            view = SetView.MAIN;
        }
    }

    function status() {
        var result = { StatusKeys.PHASE => statusPhase(), StatusKeys.HEART_RATE => _svc.currentHeartRate() };
        if (phase == Phase.REST || phase == Phase.ADJUST) {
            result[StatusKeys.REST_ENDS_AT] = _svc.epoch() + restRemainingMs() / 1000;
        }
        return result;
    }

    private function statusPhase() {
        if (paused) {
            return StatusKeys.PAUSED;
        }
        if (phase == Phase.SET) {
            return StatusKeys.SET;
        }
        if (phase == Phase.TIMED) {
            return StatusKeys.TIMED;
        }
        if (phase == Phase.REST || phase == Phase.ADJUST) {
            if (_restOver) {
                return StatusKeys.REST_OVER;
            }
            return phase == Phase.ADJUST ? StatusKeys.ADJUST : StatusKeys.REST;
        }
        if (phase == Phase.EXERCISE_DONE) {
            return StatusKeys.EXERCISE_DONE;
        }
        if (phase == Phase.PENDING) {
            return StatusKeys.PENDING;
        }
        return StatusKeys.FINISHED;
    }

    function hasStarted() {
        return phase != Phase.START && phase != Phase.EMPTY;
    }

    function isRunning() {
        return phase == Phase.SET || phase == Phase.TIMED || phase == Phase.REST || phase == Phase.ADJUST
            || phase == Phase.EXERCISE_DONE || phase == Phase.PENDING || phase == Phase.FINISHED;
    }

    function canOpenMenu() {
        return !paused && current != null && (phase == Phase.SET || phase == Phase.REST);
    }

    function restRemainingMs() {
        return _restEndMs - (paused ? _pausedAtMs : _svc.now());
    }

    function timedRemainingMs() {
        return _timedEndMs - (paused ? _pausedAtMs : _svc.now());
    }

    function currentBlock() {
        return current == null ? null : blockOf(current[PlanKeys.ID]);
    }

    function finishedBlock() {
        return _finishedBlock;
    }

    function setsOf(exerciseId) {
        var sets = results[exerciseId];
        return sets == null ? [] : sets;
    }

    function plannedWeight(exercise) {
        var override = _overrides[exercise[PlanKeys.ID]];
        if (override != null) {
            return override[EventKeys.WEIGHT];
        }
        var sets = setsOf(exercise[PlanKeys.ID]);
        for (var i = sets.size() - 1; i >= 0; i--) {
            if (sets[i][PlanKeys.WEIGHT] != null) {
                return sets[i][PlanKeys.WEIGHT];
            }
        }
        return exercise[PlanKeys.WEIGHT];
    }

    function setsDone() {
        var total = 0;
        var keys = results.keys();
        for (var i = 0; i < keys.size(); i++) {
            total += results[keys[i]].size();
        }
        return total;
    }

    function setsPlanned() {
        if (plan == null) {
            return 0;
        }
        var total = 0;
        var blocks = plan[PlanKeys.BLOCKS];
        for (var i = 0; i < blocks.size(); i++) {
            total += blocks[i][PlanKeys.ROUNDS] * blocks[i][PlanKeys.EXERCISES].size();
        }
        return total;
    }

    function blockOf(exerciseId) {
        var blocks = plan[PlanKeys.BLOCKS];
        for (var i = 0; i < blocks.size(); i++) {
            var exercises = blocks[i][PlanKeys.EXERCISES];
            for (var j = 0; j < exercises.size(); j++) {
                if (exercises[j][PlanKeys.ID].equals(exerciseId)) {
                    return blocks[i];
                }
            }
        }
        return null;
    }

    function isPending(block) {
        var pending = queue.pending();
        for (var i = 0; i < pending.size(); i++) {
            if (pending[i][PlanKeys.ID].equals(block[PlanKeys.ID])) {
                return true;
            }
        }
        return false;
    }

    function isTimed(exercise) {
        return exercise != null && PlanKeys.TIMED.equals(exercise[PlanKeys.KIND]);
    }

    private function beginSet() {
        adjust = null;
        view = SetView.MAIN;
        var block = queue.current();
        if (block == null) {
            current = null;
            phase = Phase.FINISHED;
            return;
        }
        current = queue.nextExercise();
        if (isPending(block)) {
            phase = Phase.PENDING;
            return;
        }
        phase = Phase.SET;
        _setStartMs = _svc.now();
        _setStartEpoch = _svc.epoch();
    }

    private function startTimed() {
        view = SetView.MAIN;
        timedSeconds = current[PlanKeys.SECONDS];
        _setStartMs = _svc.now();
        _setStartEpoch = _svc.epoch();
        _timedEndMs = _setStartMs + timedSeconds * 1000;
        phase = Phase.TIMED;
        _svc.vibrate(Vibe.SET);
    }

    private function elapsedTimedSeconds() {
        return (_svc.now() - _setStartMs) / 1000;
    }

    private function completeSet(seconds) {
        var exerciseId = current[PlanKeys.ID];
        var set = {
            PlanKeys.REPS => isTimed(current) ? null : current[PlanKeys.REPS],
            PlanKeys.SECONDS => seconds,
            PlanKeys.WEIGHT => plannedWeight(current),
            PlanKeys.START => _setStartEpoch,
            PlanKeys.DURATION => (_svc.now() - _setStartMs) / 1000
        };
        if (results[exerciseId] == null) {
            results[exerciseId] = [];
        }
        results[exerciseId].add(set);
        var override = _overrides[exerciseId];
        if (override != null && override[EventKeys.NEXT_ONLY]) {
            _overrides.remove(exerciseId);
        }
        lastDone = { :exercise => exerciseId, :index => results[exerciseId].size() - 1 };
        queue.setDone(exerciseId);
        log.setDone(exerciseId, set);
        _svc.vibrate(Vibe.SET);
        WorkoutStore.saveResults(results);

        var block = blockOf(exerciseId);
        if (queue.isComplete(block)) {
            _finishedBlock = block;
            phase = Phase.EXERCISE_DONE;
            _doneUntilMs = _svc.now() + Timing.EXERCISE_DONE_MS;
            return;
        }
        var next = queue.nextExercise();
        if (queue.doneCount(next[PlanKeys.ID]) < queue.doneCount(exerciseId)) {
            beginSet();
            return;
        }
        startRest(block[PlanKeys.REST]);
    }

    private function afterExerciseDone() {
        startRest(_finishedBlock[PlanKeys.REST]);
    }

    private function startRest(seconds) {
        if (seconds == null || seconds <= 0) {
            beginSet();
            return;
        }
        restTotalMs = seconds * 1000;
        _restEndMs = _svc.now() + restTotalMs;
        _warned = false;
        _restOver = false;
        adjust = null;
        phase = Phase.REST;
        var block = queue.current();
        current = block == null ? null : queue.nextExercise();
    }

    private function openAdjust() {
        var exercise = findExercise(lastDone[:exercise]);
        var set = results[lastDone[:exercise]][lastDone[:index]];
        adjust = {
            :exercise => exercise,
            AdjustField.WEIGHT => set[PlanKeys.WEIGHT],
            AdjustField.REPS => set[PlanKeys.REPS],
            AdjustField.SECONDS => set[PlanKeys.SECONDS]
        };
        adjust[:field] = adjustFields()[0];
        phase = Phase.ADJUST;
    }

    function adjustFields() {
        var exercise = adjust[:exercise];
        if (isTimed(exercise)) {
            return [AdjustField.SECONDS];
        }
        if (exercise[PlanKeys.BODYWEIGHT] == true && adjust[AdjustField.WEIGHT] == null) {
            return [AdjustField.REPS];
        }
        return [AdjustField.WEIGHT, AdjustField.REPS];
    }

    private function stepAdjust(direction) {
        var field = adjust[:field];
        var value = adjust[field];
        if (field == AdjustField.WEIGHT) {
            var next = (value == null ? 0.0 : value) + direction * Steps.WEIGHT;
            adjust[field] = next <= 0 ? null : next;
        } else if (field == AdjustField.REPS) {
            var reps = (value == null ? 0 : value) + direction * Steps.REPS;
            adjust[field] = reps < 0 ? 0 : reps;
        } else {
            var secs = (value == null ? 0 : value) + direction * Steps.SECONDS;
            adjust[field] = secs < 0 ? 0 : secs;
        }
    }

    function findExercise(exerciseId) {
        var block = blockOf(exerciseId);
        if (block == null) {
            return null;
        }
        var exercises = block[PlanKeys.EXERCISES];
        for (var i = 0; i < exercises.size(); i++) {
            if (exercises[i][PlanKeys.ID].equals(exerciseId)) {
                return exercises[i];
            }
        }
        return null;
    }
}
