package com.example.fplnotifier

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.widget.ArrayAdapter
import androidx.activity.viewModels
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.widget.doAfterTextChanged
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import com.example.fplnotifier.databinding.ActivityMainBinding
import java.time.ZoneId
import kotlinx.coroutines.launch

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private val zoneIds: List<String> by lazy { ZoneId.getAvailableZoneIds().sorted() }
    private var suppressToggleListener = false

    private val viewModel: MainViewModel by viewModels {
        MainViewModelFactory(
            application,
            SettingsRepository(applicationContext),
            ReminderRepository(applicationContext),
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        val adapter = ArrayAdapter(this, android.R.layout.simple_list_item_1, zoneIds)
        binding.inputTimezone.setAdapter(adapter)

        observeViewModel()
        setupListeners()
    }

    private fun observeViewModel() {
        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                viewModel.state.collect { state ->
                    if (binding.inputLeadHours.text?.toString() != state.leadHours) {
                        binding.inputLeadHours.setText(state.leadHours)
                    }
                    if (binding.inputPollMinutes.text?.toString() != state.pollMinutes) {
                        binding.inputPollMinutes.setText(state.pollMinutes)
                    }
                    if (binding.inputTimezone.text?.toString() != state.timezone) {
                        binding.inputTimezone.setText(state.timezone, false)
                    }
                    if (binding.toggleReminders.isChecked != state.notificationsEnabled) {
                        suppressToggleListener = true
                        binding.toggleReminders.isChecked = state.notificationsEnabled
                        suppressToggleListener = false
                    }
                    binding.textStatus.text = state.statusText
                    binding.textLastNotification.text = state.lastNotification
                        ?: getString(R.string.last_notification_none)
                }
            }
        }
    }

    private fun setupListeners() {
        binding.inputLeadHours.doAfterTextChanged { editable ->
            val text = editable?.toString()?.trim().orEmpty()
            val current = viewModel.state.value.leadHours
            if (text.isNotEmpty() && text != current) {
                text.toDoubleOrNull()?.let { viewModel.onLeadHoursChanged(it) }
            }
        }
        binding.inputPollMinutes.doAfterTextChanged { editable ->
            val text = editable?.toString()?.trim().orEmpty()
            val current = viewModel.state.value.pollMinutes
            if (text.isNotEmpty() && text != current) {
                text.toLongOrNull()?.let { viewModel.onPollMinutesChanged(it) }
            }
        }
        binding.inputTimezone.setOnItemClickListener { parent, _, position, _ ->
            val zone = parent.getItemAtPosition(position) as String
            if (zone != viewModel.state.value.timezone) {
                viewModel.onTimezoneChanged(zone)
            }
        }
        binding.toggleReminders.setOnCheckedChangeListener { _, isChecked ->
            if (suppressToggleListener) return@setOnCheckedChangeListener
            if (isChecked && !hasNotificationPermission()) {
                suppressToggleListener = true
                binding.toggleReminders.isChecked = false
                suppressToggleListener = false
                requestNotificationPermission()
                return@setOnCheckedChangeListener
            }
            viewModel.onNotificationsToggled(isChecked)
        }
    }

    private fun hasNotificationPermission(): Boolean {
        return if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            true
        } else {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                REQUEST_NOTIFICATIONS
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_NOTIFICATIONS) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            if (granted) {
                viewModel.onNotificationsToggled(true)
            }
        }
    }

    companion object {
        private const val REQUEST_NOTIFICATIONS = 1001
    }
}

class MainViewModelFactory(
    private val application: Application,
    private val settingsRepository: SettingsRepository,
    private val reminderRepository: ReminderRepository,
) : androidx.lifecycle.ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : androidx.lifecycle.ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(MainViewModel::class.java)) {
            return MainViewModel(application, settingsRepository, reminderRepository) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}
