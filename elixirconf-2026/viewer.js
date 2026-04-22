(function () {
  var tabs = Array.prototype.slice.call(document.querySelectorAll(".viewer-tab"));
  var nameEl = document.getElementById("viewer-name");
  var linesEl = document.getElementById("viewer-lines");
  var codeEl = document.getElementById("viewer-code");
  var codePreEl = document.getElementById("viewer-code-pre");
  var downloadEl = document.getElementById("viewer-download");
  var githubEl = document.getElementById("viewer-github");

  if (!tabs.length || !nameEl || !linesEl || !codeEl || !codePreEl || !downloadEl || !githubEl) {
    return;
  }

  var requestId = 0;
  var KEYWORDS = [
    "after",
    "alias",
    "and",
    "case",
    "catch",
    "cond",
    "def",
    "defdelegate",
    "defexception",
    "defguard",
    "defguardp",
    "defimpl",
    "defmacro",
    "defmacrop",
    "defmodule",
    "defp",
    "defprotocol",
    "defstruct",
    "do",
    "else",
    "end",
    "false",
    "fn",
    "for",
    "if",
    "import",
    "in",
    "nil",
    "not",
    "or",
    "quote",
    "raise",
    "receive",
    "require",
    "rescue",
    "reraise",
    "super",
    "throw",
    "true",
    "try",
    "unless",
    "unquote",
    "unquote_splicing",
    "use",
    "when",
    "with"
  ];
  var BUILTINS = [
    "assert",
    "describe",
    "elem",
    "hd",
    "import_file_if_available",
    "is_atom",
    "is_binary",
    "is_bitstring",
    "is_boolean",
    "is_float",
    "is_function",
    "is_integer",
    "is_list",
    "is_map",
    "is_map_key",
    "is_nil",
    "is_number",
    "is_pid",
    "is_struct",
    "length",
    "map_size",
    "quote",
    "raise",
    "refute",
    "require",
    "test",
    "tl",
    "tuple_size",
    "use"
  ];
  var keywordPattern = new RegExp("\\b(" + KEYWORDS.join("|") + ")\\b", "g");
  var builtinPattern = new RegExp("\\b(" + BUILTINS.join("|") + ")\\b", "g");
  var modulePattern = /\b(?:[A-Z][A-Za-z0-9_]*)(?:\.[A-Z][A-Za-z0-9_]*)*\b/g;
  var atomPattern = /(^|[^A-Za-z0-9_])(:[A-Za-z_][A-Za-z0-9_!?@]*)/g;
  var numberPattern = /\b(0x[0-9A-Fa-f]+|\d+(?:\.\d+)?)\b/g;

  function setActiveTab(activeTab) {
    tabs.forEach(function (tab) {
      var active = tab === activeTab;
      tab.classList.toggle("is-active", active);
      tab.setAttribute("aria-selected", active ? "true" : "false");
    });
  }

  function escapeHtml(text) {
    return text
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function wrapToken(className, text) {
    return '<span class="' + className + '">' + escapeHtml(text) + "</span>";
  }

  function stashToken(tokens, className, text) {
    var index = tokens.length;
    tokens.push(wrapToken(className, text));
    return "\u0000" + index + "\u0000";
  }

  function protectLiterals(text, tokens) {
    var output = "";
    var i = 0;

    while (i < text.length) {
      if (text.slice(i, i + 3) === '"""') {
        var heredocEnd = text.indexOf('"""', i + 3);
        if (heredocEnd === -1) {
          heredocEnd = text.length - 3;
        }
        output += stashToken(tokens, "tok-string", text.slice(i, heredocEnd + 3));
        i = heredocEnd + 3;
        continue;
      }

      if (text.slice(i, i + 3) === "'''") {
        var charDocEnd = text.indexOf("'''", i + 3);
        if (charDocEnd === -1) {
          charDocEnd = text.length - 3;
        }
        output += stashToken(tokens, "tok-string", text.slice(i, charDocEnd + 3));
        i = charDocEnd + 3;
        continue;
      }

      if (text[i] === "#") {
        var commentEnd = text.indexOf("\n", i);
        if (commentEnd === -1) {
          commentEnd = text.length;
        }
        output += stashToken(tokens, "tok-comment", text.slice(i, commentEnd));
        i = commentEnd;
        continue;
      }

      if (text[i] === '"' || text[i] === "'") {
        var quote = text[i];
        var j = i + 1;

        while (j < text.length) {
          if (text[j] === "\\") {
            j += 2;
            continue;
          }

          if (text[j] === quote) {
            j += 1;
            break;
          }

          j += 1;
        }

        output += stashToken(tokens, "tok-string", text.slice(i, j));
        i = j;
        continue;
      }

      output += text[i];
      i += 1;
    }

    return output;
  }

  function highlightElixir(text) {
    var tokens = [];
    var highlighted = protectLiterals(text, tokens);

    highlighted = escapeHtml(highlighted)
      .replace(modulePattern, '<span class="tok-module">$&</span>')
      .replace(keywordPattern, '<span class="tok-keyword">$1</span>')
      .replace(builtinPattern, '<span class="tok-builtin">$1</span>')
      .replace(numberPattern, '<span class="tok-number">$1</span>')
      .replace(atomPattern, '$1<span class="tok-atom">$2</span>');

    highlighted = highlighted.replace(/\u0000(\d+)\u0000/g, function (_match, index) {
      return tokens[Number(index)];
    });

    return highlighted;
  }

  function setCode(text) {
    var lineCount = text.split("\n").length;
    var numbers = [];

    for (var i = 1; i <= lineCount; i += 1) {
      numbers.push(String(i));
    }

    codeEl.innerHTML = highlightElixir(text);
    linesEl.textContent = numbers.join("\n");
    codePreEl.scrollTop = 0;
    codePreEl.scrollLeft = 0;
    linesEl.scrollTop = 0;
  }

  function loadTab(tab) {
    var currentRequest = requestId + 1;
    var file = tab.dataset.file;
    var github = tab.dataset.github;

    requestId = currentRequest;
    setActiveTab(tab);

    nameEl.textContent = file.split("/").pop();
    downloadEl.href = file;
    githubEl.href = github;
    codeEl.textContent = "Loading…";
    linesEl.textContent = "";

    fetch(file)
      .then(function (response) {
        if (!response.ok) {
          throw new Error("Unable to load file");
        }

        return response.text();
      })
      .then(function (text) {
        if (currentRequest !== requestId) {
          return;
        }

        setCode(text);
      })
      .catch(function () {
        if (currentRequest !== requestId) {
          return;
        }

        codeEl.textContent = "Unable to load file.";
        linesEl.textContent = "";
      });
  }

  tabs.forEach(function (tab) {
    tab.addEventListener("click", function () {
      loadTab(tab);
    });
  });

  codePreEl.addEventListener("scroll", function () {
    linesEl.scrollTop = codePreEl.scrollTop;
  });

  loadTab(tabs[0]);
})();
