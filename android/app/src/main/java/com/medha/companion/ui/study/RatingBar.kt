package com.medha.companion.ui.study

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.medha.companion.data.model.FSRSRating

data class RatingOption(
    val rating: FSRSRating,
    val label: String,
    val intervalText: String,
    val containerColor: Color,
    val contentColor: Color
)

/**
 * 4 bottom rating buttons (Again, Hard, Good, Easy) with predicted FSRS interval chips.
 */
@Composable
fun RatingBar(
    intervals: Map<FSRSRating, String>,
    onRate: (FSRSRating) -> Unit,
    modifier: Modifier = Modifier
) {
    val options = listOf(
        RatingOption(
            rating = FSRSRating.AGAIN,
            label = "Again",
            intervalText = intervals[FSRSRating.AGAIN] ?: "10m",
            containerColor = Color(0xFFE57373),
            contentColor = Color.White
        ),
        RatingOption(
            rating = FSRSRating.HARD,
            label = "Hard",
            intervalText = intervals[FSRSRating.HARD] ?: "1d",
            containerColor = Color(0xFFFFB74D),
            contentColor = Color.Black
        ),
        RatingOption(
            rating = FSRSRating.GOOD,
            label = "Good",
            intervalText = intervals[FSRSRating.GOOD] ?: "3d",
            containerColor = Color(0xFF81C784),
            contentColor = Color.Black
        ),
        RatingOption(
            rating = FSRSRating.EASY,
            label = "Easy",
            intervalText = intervals[FSRSRating.EASY] ?: "8d",
            containerColor = Color(0xFF64B5F6),
            contentColor = Color.Black
        )
    )

    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        for (opt in options) {
            Button(
                onClick = { onRate(opt.rating) },
                modifier = Modifier
                    .weight(1f)
                    .height(56.dp),
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = opt.containerColor,
                    contentColor = opt.contentColor
                )
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        text = opt.label,
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.Bold
                    )
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = opt.intervalText,
                        style = MaterialTheme.typography.labelSmall,
                        fontSize = 11.sp
                    )
                }
            }
        }
    }
}
