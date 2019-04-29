# == Class: znapzend::plans
#
class znapzend::plans {
  create_resources('znapzend::config', $znapzend::plans)
}
