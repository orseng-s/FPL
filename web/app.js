const state = {
  tasks: [],
  filteredTasks: [],
  selectedIds: new Set(),
};

const elements = {
  taskCount: document.querySelector('#taskCount'),
  courseCount: document.querySelector('#courseCount'),
  themeCount: document.querySelector('#themeCount'),
  selectedCount: document.querySelector('#selectedCount'),
  searchInput: document.querySelector('#searchInput'),
  courseFilter: document.querySelector('#courseFilter'),
  themeFilter: document.querySelector('#themeFilter'),
  partFilter: document.querySelector('#partFilter'),
  difficultyFilter: document.querySelector('#difficultyFilter'),
  clearFilters: document.querySelector('#clearFilters'),
  resultCount: document.querySelector('#resultCount'),
  taskGrid: document.querySelector('#taskGrid'),
  taskCardTemplate: document.querySelector('#taskCardTemplate'),
  documentTitle: document.querySelector('#documentTitle'),
  documentNotes: document.querySelector('#documentNotes'),
  documentPreview: document.querySelector('#documentPreview'),
  printDocument: document.querySelector('#printDocument'),
  copyManifest: document.querySelector('#copyManifest'),
  copyStatus: document.querySelector('#copyStatus'),
};

async function loadTasks() {
  const response = await fetch('data/tasks.json');
  if (!response.ok) {
    throw new Error(`Could not load task catalog: ${response.status}`);
  }

  state.tasks = await response.json();
  state.filteredTasks = [...state.tasks];
  hydrateFilters();
  updateMetrics();
  renderCatalog();
  renderDocument();
}

function hydrateFilters() {
  addOptions(elements.courseFilter, uniqueValues('course'));
  addOptions(elements.themeFilter, uniqueValues('theme'));
  addOptions(elements.partFilter, uniqueValues('part'));
  addOptions(elements.difficultyFilter, uniqueValues('difficulty'));
}

function uniqueValues(key) {
  return [...new Set(state.tasks.map((task) => task[key]))].sort((a, b) => String(a).localeCompare(String(b)));
}

function addOptions(select, values) {
  values.forEach((value) => {
    const option = document.createElement('option');
    option.value = value;
    option.textContent = value;
    select.append(option);
  });
}

function applyFilters() {
  const search = elements.searchInput.value.trim().toLowerCase();
  const filters = {
    course: elements.courseFilter.value,
    theme: elements.themeFilter.value,
    part: elements.partFilter.value,
    difficulty: elements.difficultyFilter.value,
  };

  state.filteredTasks = state.tasks.filter((task) => {
    const matchesSearch = !search || [
      task.title,
      task.summary,
      task.course,
      task.theme,
      task.year,
      task.season,
      ...task.subthemes,
    ].join(' ').toLowerCase().includes(search);

    return matchesSearch
      && matchesOption(task.course, filters.course)
      && matchesOption(task.theme, filters.theme)
      && matchesOption(task.part, filters.part)
      && matchesOption(task.difficulty, filters.difficulty);
  });

  renderCatalog();
}

function matchesOption(value, selected) {
  return selected === 'all' || value === selected;
}

function updateMetrics() {
  elements.taskCount.textContent = state.tasks.length;
  elements.courseCount.textContent = uniqueValues('course').length;
  elements.themeCount.textContent = uniqueValues('theme').length;
  elements.selectedCount.textContent = state.selectedIds.size;
}

function renderCatalog() {
  elements.taskGrid.textContent = '';
  elements.resultCount.textContent = `${state.filteredTasks.length} task${state.filteredTasks.length === 1 ? '' : 's'} shown`;

  if (state.filteredTasks.length === 0) {
    elements.taskGrid.innerHTML = '<p class="empty-state">No tasks match the current filters.</p>';
    return;
  }

  state.filteredTasks.forEach((task) => {
    const card = elements.taskCardTemplate.content.firstElementChild.cloneNode(true);
    card.querySelector('.course').textContent = task.course;
    card.querySelector('.part').textContent = task.part;
    card.querySelector('h3').textContent = task.title;
    card.querySelector('.summary').textContent = task.summary;

    const metadata = card.querySelector('.metadata');
    addMetadata(metadata, 'Year', `${task.season} ${task.year}`);
    addMetadata(metadata, 'Theme', `${task.theme} · ${task.subthemes.join(', ')}`);
    addMetadata(metadata, 'Points', `${task.points} pts · ${task.durationMinutes} min`);
    addMetadata(metadata, 'Source', `${task.sourcePdf}, p. ${task.pageRange}`);

    const selectButton = card.querySelector('.select-task');
    const isSelected = state.selectedIds.has(task.id);
    selectButton.textContent = isSelected ? 'Remove from document' : 'Add to document';
    selectButton.classList.toggle('selected', isSelected);
    selectButton.addEventListener('click', () => toggleTask(task.id));

    elements.taskGrid.append(card);
  });
}

function addMetadata(container, term, description) {
  const dt = document.createElement('dt');
  const dd = document.createElement('dd');
  dt.textContent = term;
  dd.textContent = description;
  container.append(dt, dd);
}

function toggleTask(taskId) {
  if (state.selectedIds.has(taskId)) {
    state.selectedIds.delete(taskId);
  } else {
    state.selectedIds.add(taskId);
  }
  updateMetrics();
  renderCatalog();
  renderDocument();
}

function selectedTasks() {
  return state.tasks
    .filter((task) => state.selectedIds.has(task.id))
    .sort((a, b) => a.course.localeCompare(b.course) || a.theme.localeCompare(b.theme) || b.year - a.year);
}

function renderDocument() {
  const tasks = selectedTasks();
  const totalMinutes = tasks.reduce((sum, task) => sum + task.durationMinutes, 0);
  const totalPoints = tasks.reduce((sum, task) => sum + task.points, 0);

  elements.documentPreview.innerHTML = `
    <div class="document-cover">
      <p class="eyebrow">Generated practice set</p>
      <h2>${escapeHtml(elements.documentTitle.value)}</h2>
      <p>${escapeHtml(elements.documentNotes.value)}</p>
      <dl>
        <div><dt>Tasks</dt><dd>${tasks.length}</dd></div>
        <div><dt>Points</dt><dd>${totalPoints}</dd></div>
        <div><dt>Estimated time</dt><dd>${totalMinutes} min</dd></div>
      </dl>
    </div>
    ${tasks.length ? renderSelectedTasks(tasks) : '<p class="empty-state">Select tasks from the catalog to build a document.</p>'}
  `;
}

function renderSelectedTasks(tasks) {
  return tasks.map((task, index) => `
    <section class="document-task">
      <p class="task-kicker">Task ${index + 1} · ${task.course} · ${task.theme} · ${task.part}</p>
      <h3>${escapeHtml(task.title)}</h3>
      <p>${escapeHtml(task.summary)}</p>
      <ul>
        <li>${task.season} ${task.year}, task ${task.taskNumber}</li>
        <li>${task.points} points · ${task.durationMinutes} minutes · ${task.difficulty}</li>
        <li>PDF source: ${escapeHtml(task.sourcePdf)} pages ${escapeHtml(task.pageRange)}</li>
      </ul>
      <div class="pdf-placeholder">Split task PDF will be embedded here.</div>
    </section>
  `).join('');
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

async function copyManifest() {
  const manifest = selectedTasks().map((task) => ({
    id: task.id,
    title: task.title,
    course: task.course,
    theme: task.theme,
    part: task.part,
    sourcePdf: task.sourcePdf,
    pageRange: task.pageRange,
  }));

  if (manifest.length === 0) {
    elements.copyStatus.textContent = 'Pick at least one task before copying a manifest.';
    return;
  }

  await navigator.clipboard.writeText(JSON.stringify(manifest, null, 2));
  elements.copyStatus.textContent = `Copied ${manifest.length} task${manifest.length === 1 ? '' : 's'} to the clipboard.`;
}

[elements.searchInput, elements.courseFilter, elements.themeFilter, elements.partFilter, elements.difficultyFilter]
  .forEach((input) => input.addEventListener('input', applyFilters));

elements.clearFilters.addEventListener('click', () => {
  elements.searchInput.value = '';
  elements.courseFilter.value = 'all';
  elements.themeFilter.value = 'all';
  elements.partFilter.value = 'all';
  elements.difficultyFilter.value = 'all';
  applyFilters();
});

elements.documentTitle.addEventListener('input', renderDocument);
elements.documentNotes.addEventListener('input', renderDocument);
elements.printDocument.addEventListener('click', () => window.print());
elements.copyManifest.addEventListener('click', copyManifest);

loadTasks().catch((error) => {
  elements.resultCount.textContent = error.message;
});
