package com.medha.companion.ui.capture

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.SheetState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

/**
 * Quick Flashcard modal bottom sheet supporting "Save" and rapid "Save & Add Another" batching.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QuickCardSheet(
    sheetState: SheetState,
    onDismiss: () -> Unit,
    onSaveCard: (front: String, back: String, hint: String?, addAnother: Boolean) -> Unit
) {
    var front by remember { mutableStateOf("") }
    var back by remember { mutableStateOf("") }
    var hint by remember { mutableStateOf("") }

    val isValid = front.trim().isNotEmpty() && back.trim().isNotEmpty()

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp, vertical = 16.dp)
        ) {
            Text(
                text = "🗂️ Quick Flashcard",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.height(16.dp))

            OutlinedTextField(
                value = front,
                onValueChange = { front = it },
                label = { Text("Front (Question / Prompt)") },
                minLines = 2,
                maxLines = 4,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.height(12.dp))

            OutlinedTextField(
                value = back,
                onValueChange = { back = it },
                label = { Text("Back (Answer / Explanation)") },
                minLines = 2,
                maxLines = 4,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.height(12.dp))

            OutlinedTextField(
                value = hint,
                onValueChange = { hint = it },
                label = { Text("Hint (optional)") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.height(20.dp))

            Row(
                modifier = Modifier.fillMaxWidth()
            ) {
                TextButton(onClick = onDismiss) {
                    Text("Cancel")
                }
                Spacer(modifier = Modifier.weight(1f))
                OutlinedButton(
                    onClick = {
                        if (isValid) {
                            onSaveCard(front.trim(), back.trim(), hint.trim().ifEmpty { null }, true)
                            front = ""
                            back = ""
                            hint = ""
                        }
                    },
                    enabled = isValid,
                    modifier = Modifier.padding(end = 8.dp)
                ) {
                    Text("+ Another")
                }
                Button(
                    onClick = {
                        if (isValid) {
                            onSaveCard(front.trim(), back.trim(), hint.trim().ifEmpty { null }, false)
                            front = ""
                            back = ""
                            hint = ""
                            onDismiss()
                        }
                    },
                    enabled = isValid
                ) {
                    Text("Save")
                }
            }

            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}
