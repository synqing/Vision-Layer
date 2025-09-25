from .ci_summary import parse as parse_ci_summary
from .ci_logs_detail import parse as parse_ci_logs_detail
from .checks_list import parse as parse_checks_list
from .pr_banner import parse as parse_pr_banner
from .pr_diff_summary import parse as parse_pr_diff_summary
from .pr_thread_summary import parse as parse_pr_thread_summary
from .ide_problems import parse as parse_ide_problems
from .ide_terminal import parse as parse_ide_terminal
from .build_artifacts_console import parse as parse_build_artifacts_console
from .hil_chart import parse as parse_hil_chart
from .hil_logs import parse as parse_hil_logs
from .serial_monitor import parse as parse_serial_monitor
from .logic_analyzer import parse as parse_logic_analyzer
from .led_camera_monitor import parse as parse_led_camera_monitor

PARSERS = {
    "CI_SUMMARY": parse_ci_summary,
    "CI_LOGS_DETAIL": parse_ci_logs_detail,
    "CHECKS_LIST": parse_checks_list,
    "PR_BANNER": parse_pr_banner,
    "PR_DIFF_SUMMARY": parse_pr_diff_summary,
    "PR_THREAD_SUMMARY": parse_pr_thread_summary,
    "IDE_PROBLEMS": parse_ide_problems,
    "IDE_TERMINAL": parse_ide_terminal,
    "BUILD_ARTIFACTS_CONSOLE": parse_build_artifacts_console,
    "HIL_CHART": parse_hil_chart,
    "HIL_LOGS": parse_hil_logs,
    "SERIAL_MONITOR": parse_serial_monitor,
    "LOGIC_ANALYZER": parse_logic_analyzer,
    "LED_CAMERA_MONITOR": parse_led_camera_monitor,
}
