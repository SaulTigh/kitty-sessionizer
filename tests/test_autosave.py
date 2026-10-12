import importlib.util
import os
import sys
import tempfile
import unittest

from kitty.session import seen_session_paths

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location('autosave', os.path.join(HERE, '..', 'kitty', 'autosave.py'))
autosave = importlib.util.module_from_spec(spec)
spec.loader.exec_module(autosave)


class FakeBoss:
    def __init__(self, windows: dict[str, list[str]]):
        self.windows = windows
        self.matches: list[str] = []

    @property
    def all_loaded_session_names(self):
        return iter(self.windows)

    def serialize_state_as_session(self, path, opts):
        self.matches.append(opts.match)
        name = os.path.basename(path).rpartition('.')[0]
        for title in self.windows.get(name, []):
            yield f'new_tab {title}'


class AutosaveTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        os.environ['KS_STATE_ROOT'] = os.path.join(self.tmp.name, 'state')
        os.makedirs(autosave.state_dir())
        self.sessions = os.path.join(self.tmp.name, 'sessions')
        os.makedirs(self.sessions)
        seen_session_paths.clear()
        self.addCleanup(seen_session_paths.clear)

    def session(self, name: str, body: str = 'old', loaded: bool = True) -> str:
        path = os.path.join(self.sessions, name + '.kitty-session')
        with open(path, 'w') as f:
            f.write(body)
        if loaded:
            seen_session_paths[name] = path
        return path

    def track(self, *paths: str) -> None:
        with open(os.path.join(autosave.state_dir(), 'active-sessions'), 'w') as f:
            f.write('\n'.join(paths) + '\n')

    def read(self, path: str) -> str:
        with open(path) as f:
            return f.read()

    def test_state_dir_is_keyed_to_the_kitty_pid(self):
        self.assertEqual(autosave.state_dir(), os.path.join(self.tmp.name, 'state', str(os.getpid())))

    def test_saves_every_tracked_live_session(self):
        a = self.session('work-a')
        b = self.session('work-b')
        self.track(a, b)
        boss = FakeBoss({'work-a': ['a1'], 'work-b': ['b1', 'b2']})

        self.assertEqual(autosave.save_all(boss), [a, b])
        self.assertEqual(self.read(a), 'new_tab a1')
        self.assertEqual(self.read(b), 'new_tab b1\nnew_tab b2')
        self.assertEqual(boss.matches, ['session:^work\\-a$', 'session:^work\\-b$'])

    def test_skips_a_session_with_no_window(self):
        a = self.session('work-a')
        self.track(a)
        boss = FakeBoss({'work-a': []})

        self.assertEqual(autosave.save_all(boss), [])
        self.assertEqual(self.read(a), 'old')

    def test_skips_a_session_kitty_has_not_loaded(self):
        a = self.session('work-a')
        self.track(a)

        self.assertEqual(autosave.save_all(FakeBoss({})), [])
        self.assertEqual(self.read(a), 'old')

    def test_skips_an_untracked_session(self):
        a = self.session('work-a')
        self.track()

        self.assertEqual(autosave.save_all(FakeBoss({'work-a': ['a1']})), [])
        self.assertEqual(self.read(a), 'old')

    def test_skips_when_kitty_loaded_the_name_from_another_file(self):
        a = self.session('work-a', loaded=False)
        seen_session_paths['work-a'] = os.path.join(self.tmp.name, 'elsewhere', 'work-a.kitty-session')
        self.track(a)

        self.assertEqual(autosave.save_all(FakeBoss({'work-a': ['a1']})), [])
        self.assertEqual(self.read(a), 'old')

    def test_skips_a_deleted_file(self):
        a = self.session('work-a')
        os.remove(a)
        self.track(a)

        self.assertEqual(autosave.save_all(FakeBoss({'work-a': ['a1']})), [])
        self.assertFalse(os.path.exists(a))

    def test_missing_state_gives_no_save(self):
        self.session('work-a')
        os.rmdir(autosave.state_dir())

        self.assertEqual(autosave.save_all(FakeBoss({'work-a': ['a1']})), [])

    def test_skips_during_a_quit(self):
        a = self.session('work-a')
        self.track(a)
        original = autosave.current_application_quit_request
        autosave.current_application_quit_request = lambda: autosave.NO_CLOSE_REQUESTED + 1
        self.addCleanup(setattr, autosave, 'current_application_quit_request', original)

        self.assertEqual(autosave.save_all(FakeBoss({'work-a': ['a1']})), [])
        self.assertEqual(self.read(a), 'old')

    def test_a_burst_of_events_schedules_one_save(self):
        calls = []
        original = autosave.add_timer
        autosave.add_timer = lambda fn, delay, repeats: calls.append((fn, delay, repeats))
        self.addCleanup(setattr, autosave, 'add_timer', original)
        boss = FakeBoss({})

        autosave.on_tab_bar_dirty(boss, None, {})
        autosave.on_focus_change(boss, None, {'focused': True})
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0][1:], (autosave.DELAY, False))

        calls[0][0](None)
        autosave.on_focus_change(boss, None, {'focused': False})
        self.assertEqual(len(calls), 2)
        calls[1][0](None)

    def test_match_turns_a_space_into_whitespace_class(self):
        self.assertEqual(autosave.match_for('my proj.x'), 'session:^my\\sproj\\.x$')


if __name__ == '__main__':
    result = unittest.main(argv=[sys.argv[0], '-v'], exit=False).result
    sys.exit(0 if result.wasSuccessful() else 1)
