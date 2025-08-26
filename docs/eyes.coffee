# Hermetic Eye Animation (Transform + Zoom + Randomization)
eyes = ['𓁿', '𓁺', '𓂀', '𓁼', '𓁹', '𓁻']
colors = ['#4a90e2','#8e44ad','#0a0a0a','#1a1a1a','#f8f9fa','#f39c12','#6c5ce7','#17a2b8','#e74c3c','#27ae60','#dc2626','#f59e0b','#7c3aed']
eyesContainer = document.getElementById 'eyes-container'

mouseX = 0;
mouseY = 0;

document.addEventListener 'mousemove', (event) ->
  clientX = event.clientX;
  clientY = event.clientY;
  mouseX = 100 * (clientX / window.visualViewport.width)
  mouseY = 100 * (clientY / window.visualViewport.height)


createEye = ->
  color = colors[Math.floor(Math.random() * colors.length)]
  eye = document.createElement 'div'
  eye.className = "eye"
  eye.textContent = eyes[Math.floor(Math.random() * eyes.length)]
  eye.style.color = color
  fontSize = Math.random() * 7 + 1
  eye.style.fontSize = "#{fontSize}rem"
  eye.style.margin = "-#{fontSize * 0.5}rem 0 0 -#{fontSize * 0.5}rem"  
  eye.style.opacity = 0.0
  eye.style.transform = "translate(#{Math.random() * 100}vw, #{Math.random() * 100}vh) scaleX(1.0) scaleY(1.0) rotateZ(0deg)"
  eyesContainer.appendChild eye

  # Smooth transform animation
  speedX = Math.random() * 0.3 - 0.15
  speedY = Math.random() * 0.6 - 0.25

  currentX = Math.random() * 100
  currentY = Math.random() * 100
  currentScale = Math.random() * 1
  currentRotation = Math.random() * 90 - 45
  currentMirror = if Math.random() > 0.5 then 1.0 else -1.0
  # currentMirror = if Math.random() > 0.5 then 0 else 180
  # currentMirrorX = currentMirrorY = 0
  distance = 100
  opacity = 0
  
  animateEye = ->
    distance = (mouseX - currentX)*(mouseX - currentX) + (mouseY - currentY)*(mouseY - currentY)

    # Randomly change speed and direction
    if Math.random() < 0.01
      speedX = Math.random() * 0.3 - 0.15
      speedY = Math.random() * 0.6 - 0.25
      currentMirror = if speedX > 0 then -1.0 else 1.0
      currentRotation = speedX * 170 + (Math.abs(speedY) * 170 * currentMirror)
      # currentMirror = if Math.random() > 0.5 then 0 else 180
      # currentMirror = if speedX < 0 then 0 else 180

    if currentMirror < 0
      currentRotation *= -1 

    if Math.random() < 0.01
      currentRotation += Math.random() * 42 - 21
      
    if distance < 300
      eye.style.textShadow = "0 0 #{20 * (distance / 300)}px #{color}"
    else 
      eye.style.textShadow = "none"
      
    
    if 'none' != eye.style.display 
      if  distance < 300
        currentX += speedX + speedX * (-3 / (distance / 300))
        currentY += speedY + speedY * (-3 / (distance / 300))
      else
        currentX += speedX
        currentY += speedY
        

    # Wrap around screen edges
    if currentX > 120 or currentX < -20 or currentY > 120 or currentY < -20
      eye.style.display = 'none'
      setTimeout (-> eye.style.display = 'block'), 1000
    if currentX > 120 then currentX = -20
    if currentX < -20 then currentX = 120
    if currentY > 120 then currentY = -20
    if currentY < -20 then currentY = 120

    # Randomly change opacity and scale
    if Math.random() < 0.01
      opacity = Math.random() * 0.5 + 0.1
      currentScale = Math.random() * 1 + 0.5

    # Update position and scale
    eye.style.transform = "translate(#{currentX}vw, #{currentY}vh) scaleX(#{currentScale * currentMirror}) scaleY(#{currentScale}) rotateZ(#{currentRotation}deg)"

    # Randomly disappear and reappear
    if Math.random() < 0.005
      opacity = 0.0
      setTimeout (-> opacity = 0.1), Math.random() * 3000
      
    if distance < 300
      eye.style.opacity = opacity + 300 / distance 
    else
      eye.style.opacity = opacity

    requestAnimationFrame animateEye

  animateEye()

# Create multiple eyes
for i in [0..30]
  setTimeout createEye, i * 500