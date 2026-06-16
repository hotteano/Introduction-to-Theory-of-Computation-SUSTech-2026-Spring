param(
    [string]$MarkdownPath = "",
    [string]$TexPath = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($MarkdownPath)) {
    $match = Get-ChildItem -Path "notes" -Filter "CS338_*Note.md" | Select-Object -First 1
    if (-not $match) {
        throw "Could not find notes/CS338_*Note.md"
    }
    $MarkdownPath = $match.FullName
}

if ([string]::IsNullOrWhiteSpace($TexPath)) {
    $TexPath = [System.IO.Path]::ChangeExtension((Resolve-Path $MarkdownPath).Path, ".tex")
}

function Escape-LaTeXText {
    param([string]$Text)
    $sb = [System.Text.StringBuilder]::new()
    foreach ($ch in $Text.ToCharArray()) {
        $code = [int][char]$ch
        switch ($code) {
            92 { [void]$sb.Append('\textbackslash{}') }
            123 { [void]$sb.Append('\{') }
            125 { [void]$sb.Append('\}') }
            35 { [void]$sb.Append('\#') }
            36 { [void]$sb.Append('\$') }
            37 { [void]$sb.Append('\%') }
            38 { [void]$sb.Append('\&') }
            95 { [void]$sb.Append('\_') }
            94 { [void]$sb.Append('\textasciicircum{}') }
            126 { [void]$sb.Append('\textasciitilde{}') }
            8745 { [void]$sb.Append('$\cap$') }
            8746 { [void]$sb.Append('$\cup$') }
            8804 { [void]$sb.Append('$\leq$') }
            8805 { [void]$sb.Append('$\geq$') }
            8800 { [void]$sb.Append('$\neq$') }
            8594 { [void]$sb.Append('$\to$') }
            8592 { [void]$sb.Append('$\leftarrow$') }
            8658 { [void]$sb.Append('$\Rightarrow$') }
            8660 { [void]$sb.Append('$\Leftrightarrow$') }
            949 { [void]$sb.Append('$\epsilon$') }
            931 { [void]$sb.Append('$\Sigma$') }
            default { [void]$sb.Append($ch) }
        }
    }
    return $sb.ToString()
}

function Convert-PlainSegment {
    param([string]$Text)
    $parts = [regex]::Split($Text, '(\*\*[^*]+\*\*)')
    $out = [System.Text.StringBuilder]::new()
    foreach ($part in $parts) {
        if ($part -match '^\*\*(.+)\*\*$') {
            [void]$out.Append('\textbf{' + (Escape-LaTeXText $Matches[1]) + '}')
        } else {
            [void]$out.Append((Escape-LaTeXText $part))
        }
    }
    return $out.ToString()
}

function Convert-Inline {
    param([string]$Line)
    $out = [System.Text.StringBuilder]::new()
    $i = 0
    while ($i -lt $Line.Length) {
        if ($i + 1 -lt $Line.Length -and $Line.Substring($i, 2) -eq '\(') {
            $end = $Line.IndexOf('\)', $i + 2)
            if ($end -ge 0) {
                [void]$out.Append($Line.Substring($i, $end - $i + 2))
                $i = $end + 2
                continue
            }
        }
        if ($Line[$i] -eq '`') {
            $end = $Line.IndexOf('`', $i + 1)
            if ($end -ge 0) {
                $code = $Line.Substring($i + 1, $end - $i - 1)
                [void]$out.Append('\texttt{' + (Escape-LaTeXText $code) + '}')
                $i = $end + 1
                continue
            }
        }

        $nextMath = $Line.IndexOf('\(', $i)
        $nextCode = $Line.IndexOf('`', $i)
        $candidates = @($nextMath, $nextCode) | Where-Object { $_ -ge 0 }
        if ($candidates.Count -eq 0) {
            $next = $Line.Length
        } else {
            $next = ($candidates | Measure-Object -Minimum).Minimum
        }
        [void]$out.Append((Convert-PlainSegment $Line.Substring($i, $next - $i)))
        $i = $next
    }
    return $out.ToString()
}

function Split-MarkdownTableRow {
    param([string]$Line)
    $trimmed = $Line.Trim()
    if ($trimmed.StartsWith('|')) { $trimmed = $trimmed.Substring(1) }
    if ($trimmed.EndsWith('|')) { $trimmed = $trimmed.Substring(0, $trimmed.Length - 1) }
    return $trimmed -split '\|'
}

function Close-List {
    param(
        [System.Collections.Generic.List[string]]$Out,
        [ref]$ListType
    )
    if ($ListType.Value -eq 'itemize') {
        $Out.Add('\end{itemize}')
        $Out.Add('')
    } elseif ($ListType.Value -eq 'enumerate') {
        $Out.Add('\end{enumerate}')
        $Out.Add('')
    }
    $ListType.Value = ''
}

$md = Get-Content -Encoding UTF8 -Path $MarkdownPath
$title = ($md | Select-Object -First 1) -replace '^#\s*',''
$out = [System.Collections.Generic.List[string]]::new()

$out.Add('\documentclass[UTF8,11pt]{ctexart}')
$out.Add('\usepackage[a4paper,margin=1.8cm]{geometry}')
$out.Add('\usepackage{amsmath,amssymb,booktabs,longtable,array}')
$out.Add('\usepackage{xcolor,hyperref,enumitem,fancyhdr,listings}')
$out.Add('\hypersetup{colorlinks=true,linkcolor=blue!45!black,urlcolor=blue!45!black}')
$out.Add('\setlength{\parindent}{0pt}')
$out.Add('\setlength{\parskip}{0.35em}')
$out.Add('\linespread{1.08}')
$out.Add('\setcounter{secnumdepth}{0}')
$out.Add('\setlist[itemize]{leftmargin=2em,itemsep=0.15em,topsep=0.2em}')
$out.Add('\setlist[enumerate]{leftmargin=2.2em,itemsep=0.15em,topsep=0.2em}')
$out.Add('\pagestyle{fancy}')
$out.Add('\setlength{\headheight}{14pt}')
$out.Add('\fancyhf{}')
$out.Add('\lhead{CS338 Review Note}')
$out.Add('\rhead{\thepage}')
$out.Add('\lstset{basicstyle=\ttfamily\small,breaklines=true,columns=fullflexible,frame=single}')
$out.Add('\title{' + (Escape-LaTeXText $title) + '}')
$out.Add('\author{}')
$out.Add('\date{\today}')
$out.Add('\begin{document}')
$out.Add('\maketitle')
$out.Add('\tableofcontents')
$out.Add('\newpage')
$out.Add('')

$inDisplayMath = $false
$inCode = $false
$listType = ''
$skipFirstTitle = $true

for ($idx = 0; $idx -lt $md.Count; $idx++) {
    $line = $md[$idx]

    if ($skipFirstTitle -and $line -match '^#\s+') {
        $skipFirstTitle = $false
        continue
    }
    $skipFirstTitle = $false

    if ($inCode) {
        if ($line.Trim() -match '^```') {
            $out.Add('\end{lstlisting}')
            $out.Add('')
            $inCode = $false
        } else {
            $out.Add($line)
        }
        continue
    }

    if ($line.Trim() -match '^```') {
        Close-List $out ([ref]$listType)
        $out.Add('\begin{lstlisting}')
        $inCode = $true
        continue
    }

    if ($inDisplayMath) {
        $out.Add($line)
        if ($line.Trim() -eq '\]') {
            $out.Add('')
            $inDisplayMath = $false
        }
        continue
    }

    if ($line.Trim() -eq '\[') {
        $out.Add('\[')
        $inDisplayMath = $true
        continue
    }

    if ($line.Trim() -eq '') {
        Close-List $out ([ref]$listType)
        $out.Add('')
        continue
    }

    if ($line.Trim() -eq '---') {
        Close-List $out ([ref]$listType)
        $out.Add('\bigskip\hrule\bigskip')
        $out.Add('')
        continue
    }

    if ($line -match '^\|') {
        Close-List $out ([ref]$listType)
        $rows = [System.Collections.Generic.List[string[]]]::new()
        while ($idx -lt $md.Count -and $md[$idx] -match '^\|') {
            if ($md[$idx] -notmatch '^\|\s*-') {
                $rows.Add((Split-MarkdownTableRow $md[$idx]))
            }
            $idx++
        }
        $idx--
        if ($rows.Count -gt 0) {
            $cols = $rows[0].Count
            $width = [Math]::Round(0.88 / [Math]::Max($cols, 1), 3)
            $spec = ('|p{' + $width + '\textwidth}') * $cols + '|'
            $out.Add('\begin{longtable}{' + $spec + '}')
            $out.Add('\hline')
            for ($r = 0; $r -lt $rows.Count; $r++) {
                $cells = @()
                for ($c = 0; $c -lt $cols; $c++) {
                    $cell = if ($c -lt $rows[$r].Count) { $rows[$r][$c].Trim() } else { '' }
                    $converted = Convert-Inline $cell
                    if ($r -eq 0) { $converted = '\textbf{' + $converted + '}' }
                    $cells += $converted
                }
                $out.Add(($cells -join ' & ') + ' \\')
                $out.Add('\hline')
            }
            $out.Add('\end{longtable}')
            $out.Add('')
        }
        continue
    }

    if ($line -match '^(#{2,6})\s+(.*)$') {
        Close-List $out ([ref]$listType)
        $level = $Matches[1].Length
        $text = Convert-Inline $Matches[2]
        switch ($level) {
            2 { $out.Add('\section{' + $text + '}') }
            3 { $out.Add('\subsection{' + $text + '}') }
            4 { $out.Add('\subsubsection{' + $text + '}') }
            default { $out.Add('\paragraph{' + $text + '}') }
        }
        $out.Add('')
        continue
    }

    if ($listType -ne '' -and $line -match '^\s{2,}\S' -and $line -notmatch '^\s*[-*]\s+' -and $line -notmatch '^\s*\d+\.\s+') {
        $out.Add((Convert-Inline $line.Trim()))
        continue
    }

    if ($line -match '^\s*-\s+(.*)$') {
        if ($listType -ne 'itemize') {
            Close-List $out ([ref]$listType)
            $out.Add('\begin{itemize}')
            $listType = 'itemize'
        }
        $out.Add('\item ' + (Convert-Inline $Matches[1]))
        continue
    }

    if ($line -match '^\s*\d+\.\s+(.*)$') {
        if ($listType -ne 'enumerate') {
            Close-List $out ([ref]$listType)
            $out.Add('\begin{enumerate}')
            $listType = 'enumerate'
        }
        $out.Add('\item ' + (Convert-Inline $Matches[1]))
        continue
    }

    Close-List $out ([ref]$listType)
    $out.Add((Convert-Inline $line))
    $out.Add('')
}

Close-List $out ([ref]$listType)
$out.Add('\end{document}')

Set-Content -Encoding UTF8 -Path $TexPath -Value $out
Write-Output "Wrote $TexPath"
