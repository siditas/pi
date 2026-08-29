# TCP relay: expose Chromium's loopback-only CDP port to WSL. No admin needed.
param([int]$Listen = 9223, [int]$Target = 9222)
$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Any, $Listen)
$listener.Start()
$conns = [Collections.ArrayList]::new()
while ($true) {
  $acc = $listener.AcceptTcpClientAsync()
  while (-not $acc.Wait(1000)) {
    # sweep: close pairs where either direction finished
    foreach ($p in @($conns)) {
      if ($p.A.IsCompleted -or $p.B.IsCompleted) { try { $p.C.Close() } catch {}; try { $p.T.Close() } catch {}; $conns.Remove($p) }
    }
  }
  $c = $acc.Result; $c.NoDelay = $true
  try {
    $t = [Net.Sockets.TcpClient]::new('127.0.0.1', $Target); $t.NoDelay = $true
    $cs = $c.GetStream(); $ts = $t.GetStream()
    [void]$conns.Add([pscustomobject]@{ C = $c; T = $t; A = $cs.CopyToAsync($ts); B = $ts.CopyToAsync($cs) })
  } catch { try { $c.Close() } catch {} }
}
