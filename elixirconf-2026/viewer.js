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

  function setActiveTab(activeTab) {
    tabs.forEach(function (tab) {
      var active = tab === activeTab;
      tab.classList.toggle("is-active", active);
      tab.setAttribute("aria-selected", active ? "true" : "false");
    });
  }

  function setCode(text) {
    var lineCount = text.split("\n").length;
    var numbers = [];

    for (var i = 1; i <= lineCount; i += 1) {
      numbers.push(String(i));
    }

    codeEl.textContent = text;
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
